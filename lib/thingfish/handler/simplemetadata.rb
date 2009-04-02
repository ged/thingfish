#!/usr/bin/ruby
#
# A metadata handler for the thingfish daemon. This handler provides
# a REST interface to metadata information when the daemon is configured
# to use a ThingFish::SimpleMetaStore.
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     urimap:
#       /metadata: simplemetadata
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
# Please see the file LICENSE in the top-level directory for licensing details.

begin
	require 'thingfish'
	require 'thingfish/metastore/simple'
	require 'thingfish/constants'
	require 'thingfish/handler'
	require 'thingfish/mixins'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

### The default metadata handler for the thingfish daemon when configured with
### a ThingFish::SimpleMetaStore.
class ThingFish::SimpleMetadataHandler < ThingFish::Handler
	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		ThingFish::Loggable,
		ThingFish::StaticResourcesHandler,
		ThingFish::ResourceLoader

	static_resources_dir "static"


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new MetadataHandler
	def initialize( path, options={} )
		super

		@metastore = nil
	end


	######
	public
	######

	### Handle a GET request
	def handle_get_request( path_info, request, response )
		self.log.debug "Handling a GET from %p" % [ path_info ]

		case path_info

		when ''
			self.handle_get_root_request( request, response )

		when UUID_URL
			uuid = $1
			self.handle_get_uuid_request( request, response, uuid )

		when PROPERTY_NAME_URL
			key = $1
			self.handle_get_key_request( request, response, key )

		else
			self.log.error "Unable to handle metadata GET request: %p" %
				[ path_info ]
		end
	end


	### Handle a PUT request
	def handle_put_request( path_info, request, response )
		self.log.debug "Handling a PUT to %p" % [ path_info ]

		case path_info

		when ''
			self.handle_update_root_request( request, response )

		when UUID_URL
			uuid = $1
			self.handle_update_uuid_request( request, response, uuid )

		when UUID_PROPERTY_URL
			uuid, key = $1, $2
			self.handle_update_key_request( request, response, uuid, key )

		else
			self.log.error "Unable to handle metadata PUT request: %p" %
				[ path_info ]
		end
	end


	### Handle a POST request
	def handle_post_request( path_info, request, response )
		self.log.debug "Handling a POST to %p" % [ path_info ]

		case path_info

		when ''
			self.handle_update_root_request( request, response )

		when UUID_URL
			uuid = $1
			self.handle_update_uuid_request( request, response, uuid )

		when UUID_PROPERTY_URL
			uuid, key = $1, $2
			self.handle_update_key_request( request, response, uuid, key )

		else
			self.log.error "Unable to handle metadata POST request: %p" %
				[ path_info ]
		end
	end


	### Handle a DELETE request
	def handle_delete_request( path_info, request, response )
		self.log.debug "Handling a DELETE on %p" % [ path_info ]

		case path_info

		when ''
			self.handle_update_root_request( request, response )

		when UUID_URL
			uuid = $1
			self.handle_update_uuid_request( request, response, uuid )

		when UUID_PROPERTY_URL
			uuid, key = $1, $2
			self.handle_delete_key_request( request, response, uuid, key )

		else
			self.log.error "Unable to handle metadata DELETE request: %p" %
				[ path_info ]
		end
	end


	### Make the content for the handler section of the index page.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "metadata/index.rhtml" )
		return tmpl.result( binding() )
	end


	### Make content for an HTML response.
	def make_html_content( values, request, response )
		template_name = uuid = key = nil

		response.data[:tagline] = 'Show me the goods, ThingFish!'
		response.data[:title] = 'metadata'

		path = self.path_info( request )
		case path
		when ''
			template_name = 'main'

		when UUID_URL
			uuid = $1
			template_name = 'uuid'

		when PROPERTY_NAME_URL
			key = $1
			template_name = 'values'

		else
			raise "Unable to build HTML content for %s" % [path]
		end

		template = self.get_erb_resource( "metadata/#{template_name}.rhtml" )
		return template.result( binding() )
	end


	#########
	protected
	#########

	### Return a list of a all metadata keys in the store
	def handle_get_root_request( request, response )
		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_keys
	end


	### Return a list of all metadata tuples for a given resource
	def handle_get_uuid_request( request, response, uuid )
		if @metastore.has_uuid?( uuid )
			response.status = HTTP::OK
			response.content_type = RUBY_MIMETYPE
			response.body = @metastore.get_properties( uuid )
		end
	end


	### Return a list of all values for metadata property
	def handle_get_key_request( request, response, key )
		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_values( key )
	end


	### Merge UUID metadata properties with values from the request body, which
	### should evaluate to be a hash of the form:
	###   {
	###     UUID1 => { property1 => value1, property2, value2 },
	###     UUID2 => { property1 => value1, property2, value2 }
	###   }
	def handle_update_root_request( request, response )
		if request.content_type == RUBY_MIMETYPE
			uuidhash = request.body

			# check uuids sent to us are valid
			unknown_uuids = uuidhash.find_all { |uuid, _| ! @metastore.has_uuid?( uuid ) }

			if unknown_uuids.empty?
				uuidhash.each do |uuid, props|
					self.update_metastore( request, uuid, props )
				end
				response.content_type = 'text/plain'
				response.status = HTTP::OK
				response.body = 'Success.'

			else
				response.status = HTTP::CONFLICT
				response.body   = unknown_uuids
			end

		else
			response.content_type = 'text/plain'
			response.status = HTTP::UNSUPPORTED_MEDIA_TYPE
			response.body = "Don't know how to handle '%s' requests." %
				[ request.content_type ]
		end
	end


	### Merge metadata properties for the specified +uuid+ with values from the
	### request body, which should evaluate to be a hash of the form:
	###   { property1 => value1, property2 => value2 }
	def handle_update_uuid_request( request, response, uuid )
		if request.content_type == RUBY_MIMETYPE

			if @metastore.has_uuid?( uuid )
				self.update_metastore( request, uuid, request.body )

				if ( request.http_method == :PUT )
					response.content_type = RUBY_MIMETYPE
					response.status = HTTP::OK
					response.body = @metastore.get_properties( uuid )
				else
					response.content_type = 'text/plain'
					response.status = HTTP::OK
					response.body = 'Success.'
				end
			else
				self.log.error "Request for metadata update to non-existant UUID #{uuid}"
				# Fallthrough to 404
			end
		else
			response.content_type = 'text/plain'
			response.status = HTTP::UNSUPPORTED_MEDIA_TYPE
			response.body = "Don't know how to handle '%s' requests." %
				[ request.content_type ]
		end
	end


	### Set a UUID metadata property with the request body, which
	### should evaluate to a string for PUT and POST.
	def handle_update_key_request( request, response, uuid, key )
		property_exists = @metastore.has_property?( uuid, key )

		@metastore.set_safe_property( uuid, key, request.body )

		response.content_type = 'text/plain'
		response.body = 'Success.'
		response.status = property_exists ? HTTP::OK : HTTP::CREATED

	rescue ThingFish::MetaStoreError => err
		# catch attempts to update system properties
		msg = "%s while updating %s: %s" %
		 	[ err.class.name, key, err.message ]
		self.log.error( msg )
		response.content_type = 'text/plain'
		response.body   = msg
		response.status	= HTTP::FORBIDDEN
	end


	### Remove a UUID metadata property.
	def handle_delete_key_request( request, response, uuid, key )
		@metastore.delete_safe_property( uuid, key )

		response.content_type = 'text/plain'
		response.body = 'Success.'
		response.status = HTTP::OK

	rescue ThingFish::MetaStoreError => err
		# catch attempts to update system properties
		msg = "%s while deleting %s: %s" %
		 	[ err.class.name, key, err.message ]
		self.log.error( msg )
		response.content_type = 'text/plain'
		response.body   = msg
		response.status	= HTTP::FORBIDDEN
	end


	### Set or update the given +uuid+'s properties from the given +props+
	### based on the http_method of the specified +request+.
	def update_metastore( request, uuid, props )
		case request.http_method
		when :POST
			@metastore.set_safe_properties( uuid, props )
		when :PUT
			@metastore.update_safe_properties( uuid, props )
		when :DELETE
			@metastore.delete_safe_properties( uuid, props )
		else
			raise "Unable to update metadata: Unknown method %s" %
				[ request.http_method ]
		end
	end

end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
