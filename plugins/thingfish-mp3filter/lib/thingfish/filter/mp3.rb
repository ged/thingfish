#!/usr/bin/ruby
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
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
# 
# :include: LICENSE
#
#---
#
# Please see the LICENSE file for licensing details.
#

begin
	require 'mp3info'

	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/mixins'
	require 'thingfish/constants'
	require 'thingfish/acceptparam'
rescue LoadError => err
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### A MP3-metadata extraction filter for ThingFish. It extracts metadata from requests 
class ThingFish::MP3Filter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Null character
	NULL = "\x0"
	
	# The Array of types this filter is interested in
	HANDLED_TYPES = [ ThingFish::AcceptParam.parse('audio/mpeg') ]
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
		return unless request.http_method == 'PUT' ||
			request.http_method == 'POST'

		request.each_body do |body, metadata|
			if self.accept?( metadata[:format] )
				mp3_metadata = self.extract_id3_metadata( body )
				request.metadata[ body ].merge!( mp3_metadata )
				self.log.debug "Extracted mp3 info: %p" % [ mp3_metadata ]
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
	###     'rev'       => 460,          # SVN rev of plugin
	###     'accepts'   => [...],        # Mimetypes the filter accepts from requests
	###     'generates' => [...],        # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }
		
		return {
			'version'   => [1,0],
			'supports'  => Mp3Info::VERSION.split('.'),
			'rev'       => Integer( SVNRev[/\d+/] || 0 ),
			'accepts'   => accepts,
			'generates' => [],
		  }
	end

	

	#########
	protected
	#########

	### Extract and normalize ID3 metadata from the MPEG layer 3 audio in the given +io+ 
	### object and return it as a hash.
	def extract_id3_metadata( io )
		info = Mp3Info.new( io.path )
		mp3_metadata = {
			:mp3_frequency => info.samplerate,
			:mp3_bitrate   => info.bitrate,
			:mp3_vbr       => info.vbr,
			:mp3_title     => info.tag.title,
			:mp3_artist    => info.tag.artist,
			:mp3_album     => info.tag.album,
			:mp3_year      => info.tag.year,
			:mp3_genre     => info.tag.genre,
			:mp3_tracknum  => info.tag.tracknum,
			:mp3_comments  => info.tag.comments,
		}

		# ID3V2 2.2.0 had three-letter tags, so map those if the artist info isn't set
		if info.hastag2? && mp3_metadata[:mp3_artist].nil?
			self.log.debug "   extracting old-style ID3v2 info" % [info.tag2.version]
			
			mp3_metadata.merge!({
				:mp3_title     => info.tag2.TT2,
				:mp3_artist    => info.tag2.TP1,
				:mp3_album     => info.tag2.TAL,
				:mp3_year      => info.tag2.TYE,
				:mp3_tracknum  => info.tag2.TRK,
				:mp3_comments  => info.tag2.COM,
				:mp3_genre     => info.tag2.TCO,
			})
		end

		if info.hastag2?
			info.tag2.keys.inject( mp3_metadata ) do |metadata, key|
				nkey = 'mp3_id3v2_' + key.to_s.downcase.gsub( /\W+/, '_' )
				metadata[ nkey.to_sym ] = info.tag2[ key ]
				metadata
			end
		end
		
		return sanitize_values( mp3_metadata )
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


