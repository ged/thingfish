#!/usr/bin/env ruby

require 'tmail'

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'
require 'thingfish/filter'


#
# A rfc2822 filter for ThingFish
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::Rfc2822Filter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# VCS Revision
	VCSRev = %q$Rev$

	# The Array of types this filter is interested in
	HANDLED_TYPES = [
		ThingFish::AcceptParam.parse('message/rfc822'),
		ThingFish::AcceptParam.parse('message/rfc2822'),
	  ]
	HANDLED_TYPES.freeze


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Make sure the version of TMail that's loaded is one that will work
	def initialize( *args ) # :notnew:
		if TMail.const_defined?( :VERSION )
			vvec = [ TMail::VERSION::MAJOR, TMail::VERSION::MINOR, TMail::VERSION::TINY ]
			tmail_verstring = "%03d.%03d.%03d" % vvec
			if tmail_verstring < '001.002.001'
				self.log.warn "This plugin is only tested with TMail 1.2.1 or greater. " +
					"You apparently have %d.%d.%d." % vvec
			end
		else
			self.log.warn "This plugin is only tested with TMail 1.2.1 or greater. " +
					"You apparently have an earlier version (no TMail::VERSION)."
		end

		super
	end


	######
	public
	######

	### Filter incoming requests
	def handle_request( request, response )
		return unless request.http_method == :PUT ||
			request.http_method == :POST

		request.each_body( true ) do |body,metadata|
			if self.accept?( metadata[:format] )
				message = TMail::Mail.parse( body.read ) or
					raise "couldn't parse message body"

				self.process_message_part( request, body, message, metadata )
			else
				self.log.debug "Skipping unhandled file type (%s)" % [metadata[:format]]
			end
		end
	end


	### Filter reponses
	def handle_response( response, request )
		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.accept?( 'text/plain' ) &&
			self.accept?( response.content_type )

		self.log.debug "Converting a %s response to text/plain" %
			[ response.content_type ]
		response.content_type = 'text/plain'
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
	###     'supports'  => [],           # Any specific version information unique to the filter
	###     'rev'       => 460,          # VCS rev of plugin
	###     'accepts'   => [...],        # Mimetypes the filter accepts from requests
	###     'generates' => [...],        # Mimetypes the filter can convert responses to
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



	#########
	protected
	#########

	### Recursively unwrap a MIME message, appending resources for each of its parts
	def process_message_part( request, body, message, metadata )
		rfc822_metadata = self.extract_rfc822_metadata( message )
		request.append_metadata_for( body, rfc822_metadata )
		self.log.debug "Appended rfc822 info: %p" % [ rfc822_metadata ]

		# Only try to append parts for multipart messages
		if message.multipart?
			self.log.debug "Message part is multipart itself, recursing for %d parts" %
				[ message.parts.length ]
			message.parts.each do |part|
				if part.multipart?
					self.process_message_part( request, body, part, metadata )
				else
					part_metadata = metadata.merge( self.extract_part_metadata(part) )
					request.append_related_resource( body, StringIO.new(part.body), part_metadata )
				end
			end
		else
			self.log.debug "Message part is monolithic -- not recursing"
		end
	end


	### Extract RFC(2)822 headers from the given message +body+, prefixing them
	### with 'rfc822_' and normalize them by downcasing and converting
	### hyphens to underscores.
	def extract_rfc822_metadata( message )
		extracted_metadata = {}
		message.header.each do |header, value|
			normalized_header, metadata_value = normalize_header( header, value )
			extracted_metadata[ normalized_header.to_sym ] = metadata_value
		end

		return extracted_metadata
	end


	### Extract and return a Hash of RFC(2)822 headers from the given message
	### +part+ (a TMail::Mail object), prefixing them with 'rfc822_' and normalize
	### them by downcasing and converting hyphens to underscores.
	def extract_part_metadata( part )
		metadata = {}
		part.header.each do |name, value|

			# Try to extract some core metadata in addition to any other headers
			case name
			when /content-disposition/i
				metadata[:title] = value[ 'filename' ]
			when /content-type/i
				metadata[:format] = value.content_type
			else
				normalized_header, metadata_value = normalize_header( name, value )
				metadata[ normalized_header.to_sym ] = metadata_value
			end

		end
		metadata[:relation] = 'part_of'

		return metadata
	end


	#######
	private
	#######

	### Transform the given MIME +header+ into metadata key/value pairs by normalizing the
	### header name, then stringifying the value.
	def normalize_header( header, value )
		normalized_header = 'rfc822:' + header.downcase.gsub( /-/, '_' )
		metadata_value = nil

		self.log.debug "Normalizing: %p => %p" % [ header, value ]
		case value
		when Array
			self.log.debug "Arrayish '%s' header; joining each with newlines" % [ header ]
			metadata_value = value.join( "\n" )
		else
			self.log.debug "Non-arrayish '%s' header (%s)" % [ header, value.class.name ]
			metadata_value = value.to_s
		end

		return normalized_header.to_sym, metadata_value
	end


end # class ThingFish::Rfc2822Filter

# vim: set nosta noet ts=4 sw=4:


