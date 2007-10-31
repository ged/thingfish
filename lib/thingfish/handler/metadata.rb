#!/usr/bin/ruby
#
# The metadata handler for the thingfish daemon. This handler provides
# a REST interface to metadata information.
#
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- metadata:
#           uris: /metadata
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


### The default metadata handler for the thingfish daemon
class ThingFish::MetadataHandler < ThingFish::Handler

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
	
	
	#########
	protected
	#########

	### Return a list of a all metadata keys in the store
	def handle_root_request( request, response )
		metadata_keys = @metastore.get_all_property_keys.collect {|k| k.to_s }

		response.status = HTTP::OK
		if request.accepts?( 'text/html' )
			content = self.get_erb_resource( 'metadata/main.rhtml' )
			response.body = content.result( binding() )
			response.headers[:content_type] = 'text/html'
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = metadata_keys
		end
	end


	### Return a list of all metadata tuples for a given resource
	def handle_uuid_request( request, response, uuid )
		
		tuples = @metastore.get_properties( uuid )
		
		response.status = HTTP::OK
		if request.accepts?( 'text/html' )
			content = self.get_erb_resource( 'metadata/uuid.rhtml' )
			response.body = content.result( binding() )
			response.headers[:content_type] = 'text/html'
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = tuples
		end		
	end


	### Return a list of all values for metadata property	
	def handle_key_request( request, response, key )	
		metadata_values = @metastore.get_all_property_values( key )

		response.status = HTTP::OK
		if request.accepts?( 'text/html' )
			content = self.get_erb_resource( 'metadata/values.rhtml' )
			response.body = content.result( binding() )
			response.headers[:content_type] = 'text/html'
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = metadata_values
		end		
	end
	
end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
