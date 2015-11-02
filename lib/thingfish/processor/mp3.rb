# -*- ruby -*-
#encoding: utf-8

require 'mp3info'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/processor' unless defined?( Thingfish::Processor )


# An in-memory metastore for testing and tryout purposes.
class Thingfish::Processor::MP3 < Thingfish::Processor
	extend Loggability

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish

	# The list of handled types
	handled_types 'audio/mpeg', 'audio/mpg', 'audio/mp3'


	# Null character
	NULL = "\x0"

	# Attached picture   "PIC"
	#    Frame size         $xx xx xx
	#    ---- mp3info is 'helpfully' cropping out frame size.
	#    Text encoding      $xx
	#    Image format       $xx xx xx
	#    Picture type       $xx
	#    Description        <textstring> $00 (00)
	#    Picture data       <binary data>
	PIC_FORMAT = 'h a3 h Z* a*'

	# Attached picture "APIC"
	#    Text encoding   $xx
	#    MIME type       <text string> $00
	#    Picture type    $xx
	#    Description     <text string according to encoding> $00 (00)
	#    Picture data    <binary data>
	APIC_FORMAT = 'h Z* h Z* a*'


	### Synchronous processor API -- extract metadata from uploaded MP3s
	def on_request( request )
		mp3info = Mp3Info.new( request.body )

		mp3_metadata = self.extract_id3_metadata( mp3info )
		request.add_metadata( mp3_metadata )

		self.extract_images( mp3info ) do |imageio, metadata|
			metadata[:title] = "Album art for %s - %s" % mp3_metadata.values_at( 'mp3:artist', 'mp3:title' )
			request.add_related_resource( imageio, metadata )
		end
	end


	### Normalize metadata from the MP3Info object and return it as a hash.
	def extract_id3_metadata( mp3info )
		self.log.debug "Extracting MP3 metadata"

		mp3_metadata = {
			'mp3:frequency' => mp3info.samplerate,
			'mp3:bitrate'   => mp3info.bitrate,
			'mp3:vbr'       => mp3info.vbr,
			'mp3:title'     => mp3info.tag.title,
			'mp3:artist'    => mp3info.tag.artist,
			'mp3:album'     => mp3info.tag.album,
			'mp3:year'      => mp3info.tag.year,
			'mp3:genre'     => mp3info.tag.genre,
			'mp3:tracknum'  => mp3info.tag.tracknum,
			'mp3:comments'  => mp3info.tag.comments,
		}

		# ID3V2 2.2.0 has three-letter tags, so map those if the artist info isn't set
		if mp3info.hastag2?
			if mp3_metadata['mp3:artist'].nil?
				self.log.debug "   extracting old-style ID3v2 info" % [mp3info.tag2.version]

				mp3_metadata.merge!({
					'mp3:title'     => mp3info.tag2.TT2,
					'mp3:artist'    => mp3info.tag2.TP1,
					'mp3:album'     => mp3info.tag2.TAL,
					'mp3:year'      => mp3info.tag2.TYE,
					'mp3:tracknum'  => mp3info.tag2.TRK,
					'mp3:comments'  => mp3info.tag2.COM,
					'mp3:genre'     => mp3info.tag2.TCO,
				})
			end
		end

		self.log.debug "  raw metadata: %p" % [ mp3_metadata ]
		return sanitize_values( mp3_metadata )
	end


	### Extract image data from ID3 information, supports both APIC (2.3) and the older style
	### PIC (2.2).  Return value is a hash with IO keys and mimetype values.
	### {
	###    io  => { format => 'image/jpeg' }
	###    io2 => { format => 'image/jpeg' }
	### }
	def extract_images( mp3info )
		self.log.debug "Extracting embedded images"
		raise LocalJumpError, "no block given" unless block_given?

		unless mp3info.hastag2?
			self.log.debug "...no id3v2 tag, so no embedded images possible."
			return
		end

		self.log.debug "...id3v2 tag present..."

		if mp3info.tag2.APIC
			self.log.debug "...extracting APIC (id3v2.3+) image data."

			images = [ mp3info.tag2.APIC ].flatten
			images.each do |img|
				blob, mime = img.unpack( APIC_FORMAT ).values_at( 4, 1 )
				yield( StringIO.new(blob),
					:format       => mime,
					:extent       => blob.length,
					:relationship => 'album-art' )
			end

		elsif mp3info.tag2.PIC
			self.log.debug "...extracting PIC (id3v2.2) image data."

			images = [ mp3info.tag2.PIC ].flatten
			images.each do |img|
				blob, type = img.unpack( PIC_FORMAT ).values_at( 4, 1 )
				mime = Mongrel2::Config.mimetypes[ ".#{type.downcase}" ] or next
				yield( StringIO.new(blob),
					:format       => mime,
					:extent       => blob.length,
					:relationship => 'album-art' )
			end

		else
			self.log.debug "...no known image tag types in tags: %p" % [ mp3info.tag2.keys.sort ]
		end
	end



	#######
	private
	#######

	### Strip NULLs from the values of the given +metadata_hash+ and return it.
	def sanitize_values( metadata_hash )
		metadata_hash.each do |k,v|
			case v
			when String
				metadata_hash[k] = v.chomp(NULL).strip
			when Array
				metadata_hash[k] = v.collect {|vv| vv.chomp(NULL).strip }
			when Numeric, TrueClass, FalseClass
				# No-op
			end
		end

		return metadata_hash.delete_if {|_,v| v.nil? }
	end


end # class Thingfish::Processor::MP3

