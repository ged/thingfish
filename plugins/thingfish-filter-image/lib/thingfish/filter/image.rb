#!/usr/bin/env ruby

require 'RMagick'

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'

#
# An image conversion/extraction filter for ThingFish
#
# == Synopsis
#
#   plugins:
#       filters:
#          image: ~
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
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::ImageFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# VCS Revision
	VCSRev = %q$Rev$

	# The default dimensions of thumbnails
	DEFAULT_THUMBNAIL_DIMENSIONS = [ 100, 100 ]


	# A struct that can represent the support in the installed ImageMagick for
	# common operations. See Magick.formats for details.
	class MagickOperations
		def initialize( ext, support_string )
			@ext = ext
			@blob, @read, @write, @multi = support_string.split('')
		end

		attr_reader :ext, :blob, :read, :write, :multi

		### Return a human-readable description of the operations spec
		def to_s
			return [
				self.has_native_blob?	? "Blob" : nil,
				self.can_read?			? "Readable" : nil,
				self.can_write?			? "Writable" : nil,
				self.supports_multi?	? "Multi" : nil,
			].compact.join(',')
		end


		### Returns +true+ if the operation string indicates that ImageMagick has native blob
		### support for the associated type
		def has_native_blob?
			return (@blob == '*')
		end


		### Returns +true+ if the operation string indicates that ImageMagick has native blob
		### support for the associated type
		def can_read?
			return (@read == 'r')
		end


		### Returns +true+ if the operation string indicates that ImageMagick has native blob
		### support for the associated type
		def can_write?
			return (@write == 'w')
		end


		### Returns +true+ if the operation string indicates that ImageMagick has native blob
		### support for the associated type
		def supports_multi?
			return (@multi == '+')
		end
	end # class MagickOperations


	# An array of mediatypes to ignore, even though ImageMagick claims it groks them
	IGNORED_MIMETYPES = %w[
		application/octet-stream
		text/html
		text/plain
		text/x-server-parsed-html
	  ]

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options={} ) # :notnew:
		options ||= {}

		@supported_formats = find_supported_formats()
		self.log.debug "Registered mimetype mapping for %d of %d support image types" %
			[ @supported_formats.keys.length, Magick.formats.length ]

		# Now convert the formats ImageMagick can read to the Accept-header style
		# list of formats the filter will accept
		@handled_types = @supported_formats.
			select {|type, op| op.can_read? }.
			collect {|type, op| ThingFish::AcceptParam.parse(type) }

		@generated_types = @supported_formats.
			select {|type, op| op.can_write? }.
			collect {|type, op| ThingFish::AcceptParam.parse(type) }

		@thumb_dimensions = options[:thumbnail_dimensions] || DEFAULT_THUMBNAIL_DIMENSIONS
		raise ThingFish::ConfigError, "invalid thumbnail dimensions %p" % [ @thumb_dimensions ] unless
			@thumb_dimensions.is_a?( Array ) && @thumb_dimensions.all? {|dim| dim.is_a?(Fixnum) }
		self.log.debug "Thumbnail dimensions are: %p" % [ @thumb_dimensions ]

		@thumb_dimensions = options[:thumbnail_dimensions] || DEFAULT_THUMBNAIL_DIMENSIONS
		raise ThingFish::ConfigError, "invalid thumbnail dimensions %p" % [ @thumb_dimensions ] unless
			@thumb_dimensions.is_a?( Array ) && @thumb_dimensions.all? {|dim| dim.is_a?(Fixnum) }
		self.log.debug "Thumbnail dimensions are: %p" % [ @thumb_dimensions ]

		super
	end


	######
	public
	######

	# The mediatypes the plugin accepts in a request, as ThingFish::AcceptParam
	# objects
	attr_reader :handled_types

	# The mediatypes the plugin can generated in a response, as
	# ThingFish::AcceptParam objects
	attr_reader :generated_types


	### Filter incoming requests -- generate a thumbnail, extract image metadata.
	def handle_request( request, response )
		return unless request.http_method == :PUT ||
					  request.http_method == :POST

		request.each_body( true ) do |body,metadata|
			next if metadata[:relation] == 'thumbnail' # No thumbnails of thumbnails

			if self.accept?( metadata[:format] )

				self.log.debug "Reading an ImageMagick image list from %p" % [ body ]
				images = case body
						 when StringIO
							 Magick::Image.from_blob( body.read )
						 else
							Magick::ImageList.new( body.path )
						 end
				self.log.debug "ImageMagick read %d images from %p" % [ images.length, body ]

				image = images.first
				image_attributes = self.extract_metadata( image )
				request.append_metadata_for( body, image_attributes )

				thumbnail, thumb_metadata = self.create_thumbnail( image, metadata[:title] )
				self.log.debug "Appending a thumbnail as a related resource"
				request.append_related_resource( body, StringIO.new(thumbnail), thumb_metadata )
			else
				self.log.debug "Skipping unhandled file type (%s)" % [metadata[:format]]
			end
		end
	end


	### Convert outgoing ruby object responses into an appropriate image format if the
	### request prefers a type other than what the resource is and ImageMagick supports
	### the conversion.
	def handle_response( response, request )
		# Don't need to modify anything on an upload or delete
		unless request.http_method == :GET
			self.log.debug "Skipping response to a non-GET request (%s)" % [ request.http_method ]
			return
		end

		response_mimetype = response.content_type or return
		return unless client_wants_transform( request, response_mimetype )
		return unless target_type = find_supported_transform( request, response_mimetype )

		# Do the conversion
		self.log.debug "Converting %s to %s" % [ response_mimetype, target_type ]
		source_image = Magick::Image.from_blob( response.body.read ).first
		target_ext = @supported_formats[ target_type.mediatype ].ext
		data = source_image.to_blob {|img| img.format = target_ext }

		response.body = data
		response.content_type = target_type.mediatype
		response.headers[:content_length] = data.length
	end


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [ 1, 0 ],    # Filter version
	###     'supports'  => [],          # The versions of ImageMagick/RMagick the plugin uses
	###     'rev'       => 460,         # VCS rev of plugin
	###     'accepts'   => [...],       # Mimetypes the filter accepts from requests
	###     'generates' => [...],       # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }
		generates = self.generated_types.map {|ap| ap.mediatype }

		supports = [
			Magick::Magick_version,
			Magick::Version
		  ]

		return {
			'version'   => [1,0],
			'supports'  => supports,
			'rev'       => VCSRev[ /: (\w+)/, 1 ] || 0,
			'accepts'   => accepts,
			'generates' => generates,
		  }
	end


	#########
	protected
	#########

	### Extract metadata from the given +image+ (a Magick::Image object) and return it in
	### a Hash.
	def extract_metadata( image )
		image_attributes = {}

		image_attributes[:'image:height']       = image.rows
		image_attributes[:'image:width']        = image.columns
		image_attributes[:'image:depth']        = image.depth
		image_attributes[:'image:density']      = image.density
		image_attributes[:'image:gamma']        = image.gamma
		image_attributes[:'image:bounding_box'] = image.bounding_box.to_s

		return image_attributes
	end


	### Create a thumbnail from the given +image+ and return it in a string along with any
	### associated metadata.
	def create_thumbnail( image, title )
		self.log.debug "Making thumbnail of max dimensions: [%d X %d]" % @thumb_dimensions
		thumb = image.resize_to_fit( *@thumb_dimensions )
		imgdata = thumb.to_blob {|img| img.format = 'JPG' }

		metadata = self.extract_metadata( thumb )
		metadata.merge!({
			:format => thumb.mime_type,
			:relation => 'thumbnail',
			:title => "Thumbnail of %s" % [ title || image.inspect ],
			:extent => imgdata.length,
		})

		self.log.debug "Made thumbnail for %p" % [ image ]
		return imgdata, metadata
	end


	#######
	private
	#######

	### Return true if the given +response_mimetype+ is not one explicitly specified by the
	### given +request+'s <code>Accept</code> header.
	def client_wants_transform( request, response_mimetype )

		# If the response wouldn't fail with NOT_ACCEPTABLE do nothing (for now)
		if request.accepts?( response_mimetype )
			self.log.debug "Skipping %s response: Already in an accepted format" %
				[ response_mimetype ]
			return false

		# Don't try to transform any format ImageMagick doesn't know about
		elsif @supported_formats[ response_mimetype ].nil?
			self.log.debug "Skipping %s response: Unsupported format (supported: %s)" %
				[ response_mimetype, @supported_formats.keys.join(',') ]
			return false

		else
			return true
		end

	end


	### Given a request and response, find and return a format that the installed ImageMagick
	### library can transform the response's entity body to.
	def find_supported_transform( request, response_mimetype )

		unless @supported_formats[ response_mimetype ].can_read?
			self.log.info "No transform for a %s response: The installed ImageMagick can't read it." %
				[ response_mimetype ]
			return nil
		end

		# Get the list of image types the client accepts. Note that this doesn't include
		# */* and image/*, as neither will ever result in a NOT_ACCEPTABLE response. If the client
		# doesn't have any explicit image preferences, just return as we can't do anything useful.
		imgtypes = request.accepted_types.
			find_all {|acceptparam| acceptparam.type == 'image' && !acceptparam.subtype.nil? }
		if imgtypes.empty?
			self.log.info "No transform for a %s response: Request has no explicitly-accepted image types."
			return nil
		end

		# Find an acceptable type we know how to write
		target_type = imgtypes.find do |param|
				@supported_formats[ param.mediatype ] && @supported_formats[ param.mediatype ].can_write?
			end

		if target_type.nil?
			self.log.info "No transform for a %s response: Installed ImageMagick can't write any of: %s" %
				[ response_mimetype, imgtypes.collect {|type| type.mediatype }.join(",") ]
		end

		return target_type
	end


	### Transform the installed ImageMagick's list of formats into AcceptParams
	### for easy comparison later.
	def find_supported_formats
		formats = {}

		# A hash of image formats and their properties. Each key in the returned
		# hash is the name of a supported image format. Each value is a string in
		# the form "BRWA". The details are in this table:
		#   B 	is "*" if the format has native blob support, and "-" otherwise.
		#   R 	is "r" if ×Magick can read the format, and "-" otherwise.
		#   W 	is "w" if ×Magick can write the format, and "-" otherwise.
		#   A 	is "+" if the format supports multi-image files, and "-" otherwise.
		Magick.formats.each do |ext,support|
			operations = MagickOperations.new( ext, support )
			unless mimetype = MIMETYPE_MAP[ '.' + ext.downcase ]
				next
			end

			# Skip some mediatypes that are too generic to be useful
			next if IGNORED_MIMETYPES.include?( mimetype )

			self.log.debug "Registering image format %s (%s)" % [ mimetype, operations ]
			formats[ mimetype ] = operations
		end

		return formats
	end
end # class ThingFish::ImageFilter

# vim: set nosta noet ts=4 sw=4:


