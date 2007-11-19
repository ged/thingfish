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

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'


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
			self.handle_root_request( request, response )
	
		when UUID_URL
			uuid = $1
			self.handle_uuid_request( request, response, uuid )
		
		when %r{^/(\w+)$}
			key = $1
			self.handle_key_request( request, response, key )
			
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
	def handle_root_request( request, response )
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_keys.collect {|k| k.to_s }
	end


	### Return a list of all metadata tuples for a given resource
	def handle_uuid_request( request, response, uuid )
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_properties( uuid )
	end


	### Return a list of all values for metadata property	
	def handle_key_request( request, response, key )	
		response.status = HTTP::OK
		response.headers[:content_type] = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_values( key )
	end
	
end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
