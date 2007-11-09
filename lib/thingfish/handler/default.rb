#!/usr/bin/ruby
#
# The default top-level handler for the thingfish daemon. This handler provides
# five basic services:
#
#   1. Top-level index <GET />
#   2. Upload a new resource <POST />
#   3. Fetch a resource by UUID <GET /51a01b12-b706-11db-a0e3-cb820d1598b5>
#   4. Overwrite a resource by UUID <PUT /51a01b12-b706-11db-a0e3-cb820d1598b5>
#   5. Delete a resource by UUID <DELETE /51a01b12-b706-11db-a0e3-cb820d1598b5>
#
# This constitutes the core of the data-storage piece of ThingFish.
#
# == Synopsis
#
#   require 'thingfish/handler/default'
#   
#   class Daemon < Mongrel::HTTPServer
#     def initialize( host, port )
#       super
#       self.register '/', ThingFish::Handler.create( 'default' )
#     end
#   end # class Daemon
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

require 'pp'
require 'time'
require 'uuidtools'
require 'mongrel'
require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'


### The default top-level handler for the thingfish daemon
class ThingFish::DefaultHandler < ThingFish::Handler

	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		ThingFish::Loggable,
		ThingFish::StaticResourcesHandler

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Config defaults
	CONFIG_DEFAULTS = {
		:html_index 	  => 'index.rhtml',
		:cache_expiration => 30.minutes,
		:resources_dir	  => nil, # Use the ThingFish::Handler default
	}

	# Pattern to match UUIDs more efficiently than uuidtools
	UUID_PATTERN = /^(#{HEX8})-(#{HEX4})-(#{HEX4})-(#{HEX2})(#{HEX2})-(#{HEX12})$/


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new DefaultHandler
	def initialize( options={} )
		super( CONFIG_DEFAULTS.merge(options) )
	end


	######
	public
	######
	
	### Handler API: Handle a GET request
	def handle_get_request( request, response )
		case request.uri.path

		# If this is a request to the root, handle it ourselves
		when '/'
			self.log.debug "Index request"
			self.handle_index_fetch_request( request, response )

		# Likewise for a request to /<a uuid>
		when UUID_URL
			self.log.debug "UUID request"
			uuid = parse_uuid( $1 )
			self.handle_resource_fetch_request( request, response, uuid )

		# Fall through to the static handler for GET requests
		else
			self.log.debug "No GET handler for %p, falling through to static" % request.uri
		end
		
	end
	alias_method :handle_head_request, :handle_get_request


	### Handler API: Handle a POST request
	def handle_post_request( request, response )
		case request.uri.path
		when '/'
			self.handle_create_request( request, response )

		when UUID_URL
			self.send_method_not_allowed_response( response, 'POST',
				%w{GET HEAD PUT DELETE} )

		else
			self.log.debug "No POST handler for %p, falling through" % request.uri
		end
	end


	### Handler API: Handle a PUT request
	def handle_put_request( request, response )
		case request.uri.path
		when '/'
			self.send_method_not_allowed_response( response, 'PUT',
				%w{GET HEAD POST} )

		when UUID_URL
			raise ThingFish::RequestError, "Multipart update not currently supported" if
				request.has_multipart_body?
			uuid = parse_uuid( $1 )
			self.handle_update_uuid_request( request, response, uuid )

		else
			self.log.debug "No PUT handler for %p, falling through" % uri
		end
	end


	### Handler API: Handle a DELETE request
	def handle_delete_request( request, response )
		case request.uri.path
		when '/'
			self.send_method_not_allowed_response( response, 'DELETE',
				%w{GET HEAD POST} )
		
		when UUID_URL
			uuid = parse_uuid( $1 )
			self.handle_delete_uuid_request( request, response, uuid )

		else
			self.log.debug "No DELETE handler for %p, falling through" % uri
		end
	end
	

	#########
	protected
	#########

	### Make the content for the handler section of the index page.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
		return tmpl.result( binding() )
	end
	
	
	### Iterate over the loaded handlers and ask each for any content it wants shown
	### on the index HTML page.
	def get_handler_index_sections
		self.log.debug "Fetching index sections for all registered handlers"
		handlers = self.daemon.classifier.handler_map.sort_by {|uri,h| uri }
		return handlers.collect do |uri,handlers|
			self.log.debug "  collecting index content from %p (%p)" % 
				[handlers.collect {|h| h.class.name}, uri]
			handlers.
				select {|h| h.is_a?(ThingFish::Handler) }.
				collect {|h| h.make_index_content( uri ) }
		end.flatten.compact
	end


	### Handle a request to fetch the index (GET or HEAD to /)
	def handle_index_fetch_request( request, response )
		if request.accepts?( 'text/html' )
			self.log.debug "Loading index resource %p" % [@options[:html_index]]
			content = self.get_erb_resource( @options[:html_index] )
			
			handler_index_sections = self.get_handler_index_sections
			html = content.result( binding() )

			response.headers[:content_type] = 'text/html'
			response.status = HTTP::OK
			response.body = html

		else
			# TODO: sweeeet
			response.body = [:something_sweet_yet_undecided]
		end
	end


	### Handle fetching a file by UUID (GET or HEAD to /{uuid})
	def handle_resource_fetch_request( request, response, uuid )
		if @filestore.has_file?( uuid )

			# Try to send a NOT MODIFIED response
			if self.can_send_cached_response?( request, uuid )
				self.log.info "Client has a cached copy of %s" % [uuid]
				response.status = HTTP::NOT_MODIFIED
				self.add_cache_headers( response, uuid )
				return
				
			else
				self.log.info "Sending resource %s" % [uuid]
				response.status = HTTP::OK
				response.headers[:content_type] = @metastore[ uuid ].format
				self.add_cache_headers( response, uuid )

				# Add content disposition headers
				self.add_content_disposition( request, response, uuid )
				
				# Send an OK status with the Content-length set to the 
				# size of the resource
				response.headers[:content_length] = @filestore.size( uuid )
				
				# HEAD requests just get the header
				unless request.http_method == 'HEAD'
					self.log.info "Setting response body to the resource IO"
					response.body = @filestore.fetch_io( uuid )
				end
			end
			
		else
			response.status = HTTP::NOT_FOUND
			response.body = "UUID '#{uuid}' not found in the filestore"
		end
	end


	### Handle a request to create a new resource with the request body as 
	### data (POST to /)
	def handle_create_request( request, response )

		uuid = nil
		
		body, metadata = request.get_body_and_metadata
		uuid = self.daemon.store_resource( body, metadata )

		response.status = HTTP::CREATED
		response.headers[:location] = '/' + uuid.to_s
		response.body = "Uploaded with ID #{uuid}"

	rescue ThingFish::FileStoreQuotaError => err
		self.log.error "Quota error while creating a resource: %s" % [ err.message ]
		raise ThingFish::RequestEntityTooLargeError, err.message
	end
	
	
	### Handle updating a file by UUID
	def handle_update_uuid_request( request, response, uuid )
		
		# :TODO: Handle slow/big uploads by returning '202 Accepted' and spawning
		#         a handler thread?
		new_resource = ! @filestore.has_file?( uuid )
		body, metadata = request.get_body_and_metadata
		self.daemon.store_resource( body, metadata, uuid )
		
		if new_resource
			response.status = HTTP::CREATED
			response.headers[:location] = '/' + uuid.to_s
			response.body = "Uploaded with ID #{uuid}"
		else
			response.status = HTTP::OK
			response.body = "UUID '#{uuid}' updated"
		end
	rescue ThingFish::FileStoreQuotaError => err
		self.log.error "Quota error while updating a resource: %s" % [ err.message ]
		raise ThingFish::RequestEntityTooLargeError, err.message
	end


	### Handle deleting a file by UUID
	def handle_delete_uuid_request( request, response, uuid )
		if @filestore.has_file?( uuid )
			@filestore.delete( uuid )
			@metastore.delete_properties( uuid )
			response.status = HTTP::OK
			response.body = "Resource '#{uuid}' deleted"
		else
			response.status = HTTP::NOT_FOUND
			response.body = "Resource '#{uuid}' not found"
		end
	end
	
	
	### Returns true if the given +request+'s headers indicate that the local copy
	### of the data corresponding to the specified +uuid+ are cached remotely, and
	### the client can just use the cached version. This usually means that the
	### handler will send a 304 NOT MODIFIED.
	def can_send_cached_response?( request, uuid )
		metadata = @metastore[ uuid ]
		return request.is_cached_by_client?( metadata.checksum, metadata.modified )
	end
	
	
	### Add cache control headers to the given +response+ for the specified +uuid+.
	def add_cache_headers( response, uuid )
		self.log.debug "Adding cache headers to response for %s" % [uuid]
		
		response.headers[ :etag ] = %q{"%s"} % [@metastore[ uuid ].checksum]
		response.headers[ :expires ] = 1.year.from_now.httpdate
	end
	

	### Add content disposition handlers to the given +response+ for the
	### specified +uuid+ if the 'attach' query argument exists.  As described in
	### RFC 2183, this is an optional, but convenient header when using UUID-keyed 
	### resources.
	def add_content_disposition( request, response, uuid )
		return unless request.query_args.has_key?('attach')
		
		disposition = []
		disposition << 'attachment'

		if (( filename = @metastore[ uuid ].title ))
			disposition << %{filename="%s"} % [ filename ]
		end

		if (( modtime = @metastore[ uuid ].modified ))
			modtime = Time.parse( modtime ) unless modtime.is_a?( Time )
			disposition << %{modification-date="%s"} % [ modtime.rfc822 ]
		end

		response.headers[ :content_disposition ] = disposition.join('; ')
	end



	#######
	private
	#######
	
	### A more-efficient version of UUIDTools' UUID parser -- see
	### experiments/bench-uuid-parse.rb in the subversion source.
	def parse_uuid( uuid_string )
		unless match = UUID_PATTERN.match( uuid_string )
			raise ArgumentError, "Invalid UUID %p." % [uuid_string]
		end

		uuid_components = match.captures

		time_low = uuid_components[0].to_i( 16 )
		time_mid = uuid_components[1].to_i( 16 )
		time_hi_and_version = uuid_components[2].to_i( 16 )
		clock_seq_hi_and_reserved = uuid_components[3].to_i( 16 )
		clock_seq_low = uuid_components[4].to_i( 16 )

		nodes = []
		0.step( 11, 2 ) do |i|
			nodes << uuid_components[5][ i, 2 ].to_i( 16 )
		end

		return UUID.new( time_low, time_mid, time_hi_and_version,
		                 clock_seq_hi_and_reserved, clock_seq_low, nodes )
	end

end # ThingFish::DefaultHandler

# vim: set nosta noet ts=4 sw=4:
