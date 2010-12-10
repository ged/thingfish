#!/usr/bin/env ruby

require 'mp3info'

require 'thingfish'
require 'thingfish/filter'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


#
# An MP3 metadata-extraction filter for ThingFish
#
# == Synopsis
#
#   plugins:
#       filters:
#          mp3: {}
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the LICENSE file for licensing details.
#
class ThingFish::MP3Filter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# VCS Revision
	VCSRev = %q$Rev$

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

	# The Array of types this filter is interested in
	HANDLED_TYPES = [ 'audio/mpeg', 'audio/mpg', 'audio/mp3' ].
		collect {|mimetype| ThingFish::AcceptParam.parse(mimetype) }
	HANDLED_TYPES.freeze


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options={} ) # :notnew:
		super
	end


	######
	public
	######

	### Extract metadata from incoming requests if their content-type headers
	### indicate its MP3 data.
	def handle_request( request, response )
		return unless request.http_method == :PUT ||
			request.http_method == :POST

		request.each_body do |body, metadata|
			if self.accept?( metadata[:format] )

				id3 = Mp3Info.new( body.path )
				mp3_metadata = self.extract_id3_metadata( id3 )

				# Append any album images as related resources
				self.extract_images( id3 ).each do |io, metadata|
					metadata[:title] = "Album art for %s - %s" % mp3_metadata.values_at( :'mp3:artist', :'mp3:title' )
					request.append_related_resource( body, io, metadata )
				end

				request.append_metadata_for( body, mp3_metadata )
				self.log.debug "Extracted mp3 info: %p" % [ mp3_metadata.keys ]
			else
				self.log.debug "Skipping unhandled file type (%s)" % [metadata[:format]]
			end
		end
	end


	### Filter outgoing responses (no-op currently)
	def handle_response( response, request )
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [1, 0],       # Filter version
	###     'supports'  => [0, 5, 1],    # Mp3Info version
	###     'rev'       => 460,          # VCS rev of plugin
	###     'accepts'   => [...],        # Mimetypes the filter accepts from requests
	###     'generates' => [...],        # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }

		return {
			'version'   => [1,0],
			'supports'  => Mp3Info::VERSION.split('.'),
			'rev'       => VCSRev[ /: (\w+)/, 1 ] || 0,
			'accepts'   => accepts,
			'generates' => [],
		  }
	end



	#########
	protected
	#########

	### Normalize metadata from the MP3Info object and return it as a hash.
	def extract_id3_metadata( id3 )
		self.log.debug "Extracting MP3 metadata"

		mp3_metadata = {
			:'mp3:frequency' => id3.samplerate,
			:'mp3:bitrate'   => id3.bitrate,
			:'mp3:vbr'       => id3.vbr,
			:'mp3:title'     => id3.tag.title,
			:'mp3:artist'    => id3.tag.artist,
			:'mp3:album'     => id3.tag.album,
			:'mp3:year'      => id3.tag.year,
			:'mp3:genre'     => id3.tag.genre,
			:'mp3:tracknum'  => id3.tag.tracknum,
			:'mp3:comments'  => id3.tag.comments,
		}

		# ID3V2 2.2.0 has three-letter tags, so map those if the artist info isn't set
		if id3.hastag2?
			if mp3_metadata[:'mp3:artist'].nil?
				self.log.debug "   extracting old-style ID3v2 info" % [id3.tag2.version]

				mp3_metadata.merge!({
					:'mp3:title'     => id3.tag2.TT2,
					:'mp3:artist'    => id3.tag2.TP1,
					:'mp3:album'     => id3.tag2.TAL,
					:'mp3:year'      => id3.tag2.TYE,
					:'mp3:tracknum'  => id3.tag2.TRK,
					:'mp3:comments'  => id3.tag2.COM,
					:'mp3:genre'     => id3.tag2.TCO,
				})
			end
		end

		return sanitize_values( mp3_metadata )
	end


	### Extract image data from id3 information, supports both APIC (2.3) and the older style
	### PIC (2.2).  Return value is a hash with IO keys and mimetype values.
	### {
	###    io  => { format => 'image/jpeg' }
	###    io2 => { format => 'image/jpeg' }
	### }
	def extract_images( id3 )
		self.log.debug "Extracting embedded images"
		data = {}

		unless id3.hastag2?
			self.log.debug "...no id3v2 tag, so no embedded images possible."
			return
		end

		self.log.debug "...id3v2 tag present..."

		if id3.tag2.APIC
			self.log.debug "...extracting APIC (id3v2.3+) image data."

			images = [ id3.tag2.APIC ].flatten
			images.each do |img|
				blob, mime = img.unpack( APIC_FORMAT ).values_at( 4, 1 )
				data[ StringIO.new(blob) ] = {
					:format   => mime,
					:extent   => blob.length,
					:relation => 'album-art'
				}
			end

		elsif id3.tag2.PIC
			self.log.debug "...extracting PIC (id3v2.2) image data."

			images = [ id3.tag2.PIC ].flatten
			images.each do |img|
				blob, type = img.unpack( PIC_FORMAT ).values_at( 4, 1 )
				mime = MIMETYPE_MAP[ ".#{type.downcase}" ] or next
				data[ StringIO.new(blob) ] = {
					:format   => mime,
					:extent   => blob.length,
					:relation => 'album-art'
				}
			end

		else
			self.log.debug "...no known image tag types in tags: %p" % [ id3.tag2.keys.sort ]
		end

		return data
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
			else
				self.log.debug "Sanitizing a '%s' metadata field" % [v.class.name]
				metadata_hash[k] = '(unknown)'
			end
		end

		return metadata_hash
	end

end # class ThingFish::Mp3Filter

# vim: set nosta noet ts=4 sw=4:
