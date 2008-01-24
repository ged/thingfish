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
#     handlers:
#		- simplemetadata: /metadata
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
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

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
	def initialize( options={} )
		super

		@metastore = nil
	end


	######
	public
	######
	
	### Handle a GET request
	def handle_get_request( request, response )

		case request.path_info
			
		when '/', ''
			self.handle_get_root_request( request, response )
	
		when UUID_URL
			uuid = $1
			self.handle_get_uuid_request( request, response, uuid )
		
		when %r{^/(\w+)$}
			key = $1
			self.handle_get_key_request( request, response, key )
			
		else
			self.log.error "Unable to handle metadata request: %p" % 
				[ request.path_info ]
			return			
		end		
	end


	### Handle a PUT request
	def handle_put_request( request, response )

		case request.path_info
			
		when '/', ''
			self.handle_update_root_request( request, response )
	
		when UUID_URL
			uuid = $1
			self.handle_update_uuid_request( request, response, uuid )

		when %r{^/(#{UUID_REGEXP})/(\w+)$}
			uuid, key = $1, $2
			self.handle_update_key_request( request, response, uuid, key )
			
		else
			self.log.error "Unable to handle metadata request: %p" % 
				[ request.path_info ]
			return			
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

		case request.path_info
		when '', '/'
			template_name = 'main'

		when UUID_URL
			uuid = $1
			template_name = 'uuid'

		when %r{^/(\w+)$}
			key = $1
			template_name = 'values'

		else
			raise "Unable to build HTML content for %s" % [request.path_info]
		end
		
		template = self.get_erb_resource( "metadata/#{template_name}.rhtml" )
		return template.result( binding() )
	end
	
	
	### Overridden: check to be sure the metastore used is a 
	### ThingFish::SimpleMetaStore.
	def listener=( listener )
		raise ThingFish::ConfigError, 
			"This handler must be used with a ThingFish::SimpleMetaStore." unless
			listener.metastore.is_a?( ThingFish::SimpleMetaStore )
		super
	end
	

	#########
	protected
	#########

	### Return a list of a all metadata keys in the store
	def handle_get_root_request( request, response )
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_keys.collect {|k| k.to_s }
	end


	### Return a list of all metadata tuples for a given resource
	def handle_get_uuid_request( request, response, uuid )
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_properties( uuid )
	end


	### Return a list of all values for metadata property	
	def handle_get_key_request( request, response, key )	
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_values( key )
	end


	### Merge UUID metadata properties with values from the request body, which 
	### should evaluate to be a hash of the form:
	###   {
	###     UUID1 => { property1 => value1, property2, value2 },
	###     UUID2 => { property1 => value1, property2, value2 }
	###   }
	def handle_update_root_request( request, response )
		if request.headers[:content_type] == RUBY_MIMETYPE
			# Unimplemented
		else
			response.headers[:content_type] = 'text/plain'
			response.status = HTTP::UNSUPPORTED_MEDIA_TYPE
			response.body = "Don't know how to handle '%s' requests." %
				[ request.headers[:content_type] ]
		end
	end


	### Merge metadata properties for the specified +uuid+ with values from the
	### request body, which should evaluate to be a hash of the form:
	###   { property1 => value1, property2, value2 }
	def handle_update_uuid_request( request, response, uuid )
		if request.headers[:content_type] == RUBY_MIMETYPE
			prophash = request.body

			if @metastore.has_uuid?( uuid )
				@metastore.update_safe_properties( uuid, prophash )
		
				response.headers[:content_type] = 'text/plain'
				response.status = HTTP::OK
				response.body = 'Success.'
			else
				self.log.error "Request for metadata update to non-existant UUID #{uuid}"
				# Fallthrough to 404
			end
		else
			response.headers[:content_type] = 'text/plain'
			response.status = HTTP::UNSUPPORTED_MEDIA_TYPE
			response.body = "Don't know how to handle '%s' requests." %
				[ request.headers[:content_type] ]
		end
	end


	### Set a UUID metadata property with the request body, which 
	### should evaluate to a string.
	def handle_update_key_request( request, response, uuid, key )	
		new_property = ! @metastore.has_property?( uuid, key )

		@metastore.set_safe_property( uuid, key, request.body )

		response.headers[:content_type] = 'text/plain'
		response.status = new_property ? HTTP::CREATED : HTTP::OK
		response.body = 'Success.'

	rescue ThingFish::MetaStoreError => err
		msg = "%s while updating %s: %s" %
		 	[ err.class.name, key, err.message ]
		self.log.error( msg )
		response.body   = msg
		response.status	= HTTP::FORBIDDEN
	end
	
end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
