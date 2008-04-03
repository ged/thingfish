#!/usr/bin/ruby
# 
# An EXIF metadata-extraction filter for ThingFish, using ruby's exifr module.
# http://exifr.rubyforge.org/
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          exif: ~
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

require 'exifr'
require 'thingfish'
require 'thingfish/filter'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### An EXIF metadata-extraction filter for ThingFish.
###  
class ThingFish::ExifFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$
	
	# The Array of types this filter is interested in
	HANDLED_TYPES = [
		ThingFish::AcceptParam.parse('image/jpeg'),
		ThingFish::AcceptParam.parse('image/tiff')
	]
	HANDLED_TYPES.freeze


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	###
	def initialize( options={} ) # :notnew:
		super
	end

	
	######
	public
	######

	### Extract metadata from incoming requests if their content-type headers
	### indicate its JPEG or TIFF data.
	###
	def handle_request( request, response )

		return unless request.http_method == 'PUT' ||
					  request.http_method == 'POST'

		request.each_body do |body, metadata|
			case metadata[:format].downcase

		    # JPEG image
			#
			when 'image/jpeg'
				parser = EXIFR::JPEG.new( body )

				attributes = %w{ width height comment bits }
				attributes += parser.exif.to_hash.keys.
							  map { |exif_key| exif_key.to_s } if parser.exif?

		    # TIFF image
			#
			when 'image/tiff'
				parser = EXIFR::TIFF.new( body )

				attributes = %w{ width height size }
				attributes += parser.to_hash.keys.map { |exif_key| exif_key.to_s }

			# We don't handle anything else.
			#
			else
				return
			end

			exif_metadata = self.extract_exif( parser, attributes )

			request.append_metadata_for( body, exif_metadata )
			self.log.debug "Extracted exif info: %p" % [ exif_metadata.keys ]
		end
	end


	### Filter outgoing responses (no-op currently)
	###
	def handle_response( response, request )
	end


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [ 1, 0 ],                    # Filter version
	###     'supports'  => [],                          # Unused
	###     'rev'       => 460,                         # SVN rev of plugin
	###     'accepts'   => [''],                        # Mimetypes the filter accepts from requests
	###     'generates' => ['application/xhtml+xml'],   # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }
		return {
			'version'   => [1,0],
			'supports'  => [],
			'rev'       => Integer( SVNRev[/\d+/] || 0 ),
			'accepts'   => accepts,
			'generates' => [],
		  }
	end
	

	### Return an Array of ThingFish::AcceptParam objects which describe which
	### content types the filter is interested in. The default returns */*,
	### which indicates that it is interested in all requests/responses.
	###
	def handled_types
		return HANDLED_TYPES
	end


	#########
	protected
	#########

	### Pull the exif +attributes+ from the image file, using the given +parser+.
	### Return a hash of parsed values.
	###
	def extract_exif( parser, attributes=[] )

		exif = {}
		attributes.each do |exif_key|
			exif_val = parser.send( exif_key )
			exif_val = exif_val.to_i if exif_val.is_a?( EXIFR::TIFF::Orientation )
			exif[ 'exif_' + exif_key ] = exif_val
		end

		return exif
	end

end # class ThingFish::ExifFilter


# vim: set nosta noet ts=4 sw=4:


