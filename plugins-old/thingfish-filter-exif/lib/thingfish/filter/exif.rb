#!/usr/bin/env ruby
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
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
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

	# VCS Revision
	VCSRev = %q$Rev$

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

		return unless request.http_method == :PUT ||
					  request.http_method == :POST

		request.each_body do |body, metadata|
			case metadata[:format].downcase

		    # JPEG image
			#
			when 'image/jpeg'
				parser = EXIFR::JPEG.new( body )

				attributes = %w{ width height comment bits }
				attributes += parser.exif.to_hash.keys.
							  map {|exif_key| exif_key.to_s } if parser.exif?

		    # TIFF image
			#
			when 'image/tiff'
				parser = EXIFR::TIFF.new( body )

				attributes = %w{ width height size }
				attributes += parser.to_hash.keys.map {|exif_key| exif_key.to_s }

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
	###     'rev'       => 460,                         # VCS rev of plugin
	###     'accepts'   => [''],                        # Mimetypes the filter accepts from requests
	###     'generates' => ['application/xhtml+xml'],   # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }
		return {
			'version'   => [1,0],
			'supports'  => [],
			'rev'       => VCSRev[ /: (\w+)/, 1 ] || 0,
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
			self.log.debug "  normalizing %p..." % [ exif_key ]
			exif_val = parser.send( exif_key )

			if exif_val.is_a?( EXIFR::TIFF::Orientation )
				exif_val = exif_val.to_i
			elsif exif_key == 'gps_latitude'
				self.log.debug "    gps lat values: %p" % [ exif_val ]
				deg, min, secs = *exif_val
				hemisphere = parser.gps_latitude_ref
				exif_val = ( deg + (min / 60.0) + (secs / 3600) ) * ( hemisphere == 'S' ? -1 : 1 )
			elsif exif_key == 'gps_longitude'
				self.log.debug "    gps long values: %p" % [ exif_val ]
				deg, min, secs = *exif_val
				hemisphere = parser.gps_longitude_ref
				exif_val = ( deg + min / 60.0 + secs / 3600 ) * ( hemisphere == 'W' ? -1 : 1 )
			end

			keyname = exif_key.gsub( /_(\w)/ ) { $1.upcase }
			exif[ ('exif:' + keyname).to_sym ] = exif_val
		end

		return exif
	end

end # class ThingFish::ExifFilter


# vim: set nosta noet ts=4 sw=4:

