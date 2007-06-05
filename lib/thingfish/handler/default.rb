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
#:include: LICENSE
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

	# Pattern that matches requests to /«uuid»
	UUID_URL = %r{^/(#{UUID_REGEXP})$}

	# Buffer output in 4k chunks
	CHUNK_SIZE = 4096

	# Config defaults
	CONFIG_DEFAULTS = {
		:html_index => 'index.html',
		:cache_expiration => 30.minutes,
		:resources_dir => nil, # Use the ThingFish::Handler default
	}

	# Pattern to match UUIDs more efficiently than uuidtools
	UUID_PATTERN = /^(#{HEX8})-(#{HEX4})-(#{HEX4})-(#{HEX2})(#{HEX2})-(#{HEX12})$/

	# Pattern to match the contents of ETag and If-None-Match headers
	ENTITY_TAG_PATTERN = %r{
		(w/)?		# Weak flag
		"			# Opaque-tag
			([^"]+)		# Quoted-string
		"			# Closing quote
	  }ix


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new DefaultHandler
	def initialize( options={} )
		super( CONFIG_DEFAULTS.merge(options) )

		@filestore = nil
		@metastore = nil
	end


	######
	public
	######
	
	### Handle a request
	def process( request, response )
		super

		uri = request.params['REQUEST_URI']
		
		case uri

		# If this is a request to the root, handle it ourselves
		when '/'
			self.handle_index_request( request, response )

		# Likewise for a request to /<a uuid>
		when UUID_URL
			uuid = parse_uuid( $1 )
			self.handle_uuid_request( request, response, uuid )

		# The default handler doesn't care about anything else
		else
			response.start( HTTP::NOT_FOUND ) do |headers, out|
				out.write( "Resource not found" )
			end
			self.log.error "No handler mapping for %p, falling through to static" % uri
		end
		
	rescue StandardError => err
		self.log.error "500 SERVER ERROR: %s" % [err.message]
		self.log.debug {"  " + err.backtrace.join("\n  ") }

		# If the response is already at least partially sent, we can't really do 
		# anything.
		if response.header_sent
			self.log.error "Exception occurred after headers were already sent."
			raise

		# If it's not, return a 500 response
		else
			response.reset
			response.start( HTTP::SERVER_ERROR, true ) do |headers, out|
				out.write( err.message )
			end
		end
	end


	#########
	protected
	#########

	### Handle a request for the toplevel index
	def handle_index_request( request, response )
		method  = request.params['REQUEST_METHOD']
		accepts = request.params['HTTP_ACCEPT']

		case method
		when 'GET'
			self.handle_index_get( request, response )

		when 'POST'
			self.handle_index_post( request, response )

		# 'DELETE' and 'PUT' aren't allowed for /
		else
			response.start( HTTP::METHOD_NOT_ALLOWED, true ) do |headers, out|
				headers['Allow'] = 'GET, POST'
				out.write( "Method not allowed." )
			end
		end
	end


	### Handle a GET request to '/'
	def handle_index_get( request, response )

		# :TODO: dispatch on request.params['HTTP_ACCEPT']
		self.log.debug "Loading index resource %p" % [@options[:html_index]]
		content = self.get_erb_resource( @options[:html_index] )

		response.start( HTTP::OK, true ) do |headers, out|
			headers['Content-Type'] = 'text/html'
			out.write( content.result(binding()) )
		end

	end


	### Handle a POST request to '/'
	def handle_index_post( request, response )

		# Store the resource with a new UUID
		uuid = UUID.timestamp_create
		self.store_resource( request, uuid.to_s )

		# Create the response
		response.start( HTTP::CREATED, true ) do |headers, out|
			headers['Location'] = '/' + uuid.to_s
			out.write( "Uploaded with ID #{uuid}" )
		end
	rescue ThingFish::FileStoreQuotaError => err
		return handle_upload_error( response, uuid, 
			HTTP::REQUEST_ENTITY_TOO_LARGE, err.message )
	end
	

	### Handle a request for a UUID
	def handle_uuid_request( request, response, uuid )
		method  = request.params['REQUEST_METHOD']
		accepts = request.params['HTTP_ACCEPT']

		case method
		when 'GET', 'HEAD'
			self.handle_get_uuid_request( request, response, uuid )
	
		when 'PUT'
			self.handle_put_uuid_request( request, response, uuid )
	
		when 'DELETE'
			self.handle_delete_uuid_request( request, response, uuid )

		else
			response.start( HTTP::METHOD_NOT_ALLOWED, true ) do |headers, out|
				headers['Allow'] = 'HEAD, GET, PUT, DELETE'
				out.write( "Method not allowed." )
			end
		end

	end


	### Handle fetching a file by UUID
	def handle_get_uuid_request( request, response, uuid )
		if @filestore.has_file?( uuid )

			# Try to send a NOT MODIFIED response
			if self.can_send_cached_response?( request, uuid )
				response.status = HTTP::NOT_MODIFIED
				self.add_cache_headers( response, uuid )
				response.send_status
				response.send_header
				
			else

				# :TODO: content negotiation
				
				self.log.info "Sending resource %s" % [uuid]
				response.status = HTTP::OK
				response.header['Content-type'] = @metastore[ uuid.to_s ].format
				self.add_cache_headers( response, uuid )
				
				# Send an OK status with the Content-length set to the 
				# size of the resource
				response.send_status( @filestore.size(uuid) )
				response.send_header
				
				# HEAD requests just get the header
				unless request.params['REQUEST_METHOD'] == 'HEAD'
					self.do_buffered_filestore_read( uuid, response )
				end
			end
			
			response.finished
		else
			response.start( HTTP::NOT_FOUND, true ) do |headers, out|
				out.write( "UUID '#{uuid}' not found in the filestore" )
			end			
		end
	end


	### Handle uploading a file by UUID
	def handle_put_uuid_request( request, response, uuid )
		
		# :TODO: Handle slow/big uploads by returning '202 Accepted' and spawning
		#         a handler thread?
		new_resource = ! @filestore.has_file?( uuid )
		self.store_resource( request, uuid )
		
		# :TODO: dispatch on request.params['HTTP_ACCEPT']
		if new_resource
			response.start( HTTP::CREATED, true ) do |headers, out|
				headers['Location'] = '/' + uuid.to_s
				out.write( "Uploaded with ID #{uuid}" )
			end
		else
			response.start( HTTP::OK, true ) do |headers, out|
				out.write( "UUID '#{uuid}' updated" )
			end
		end
	rescue ThingFish::FileStoreQuotaError => err
		return handle_upload_error( response, uuid, 
			HTTP::REQUEST_ENTITY_TOO_LARGE, err.message, new_resource )
	end


	### Handle deleting a file by UUID
	def handle_delete_uuid_request( request, response, uuid )
		if @filestore.has_file?( uuid )
			@filestore.delete( uuid )
			response.start( HTTP::OK, true ) do |headers, out|
				out.write( "UUID '#{uuid}' deleted" )
			end
		else
			response.start( HTTP::NO_CONTENT, true ) do |headers, out|
				out.write( "UUID '#{uuid}' not found in the filestore" )
			end
		end
	end


	### Store the data from the upload in the specified +request+ in the filestore
	### create/update any associated metadata.
	def store_resource( request, uuid )

		# Store the data
		checksum = @filestore.store_io( uuid, request.body )

		# Store some default metadata about the resource
		@metastore[ uuid ].checksum = checksum
		@metastore.extract_default_metadata( uuid, request )

		self.log.info "Created new resource %s (%s, %0.2f KB), checksum is %s" % [
			uuid,
			request.params['CONTENT_TYPE'],
			Integer(request.params['HTTP_CONTENT_LENGTH']) / 1024.0,
			@metastore[ uuid ].checksum
		  ]
		
		return checksum
	end
	

	### Generate an error response using the specified +status_code+ and +message+
	### for the upload of the resource for the given +uuid+. Handles cleanup of
	### any uploaded data or metadata.
	def handle_upload_error( response, uuid, status_code, message, new_resource=true )
		self.log.error "Error while creating new resource: %s (%d)" %
			[ message, status_code ]

		if new_resource
			@metastore.delete_properties( uuid.to_s )
			@filestore.delete( uuid.to_s )
		end
		
		response.start( status_code, true ) do |headers, out|
			out.write( message )
		end
	end
	
	
	### Buffer the resource specified by +uuid+ from the filestore to the given 
	### +response+.
	def do_buffered_filestore_read( uuid, response )
		@filestore.fetch_io( uuid ) do |io|
			buf = ''
			while io.read( CHUNK_SIZE, buf )
				until buf.empty?
					bytes = response.write( buf )
					buf.slice!( 0, bytes )
				end
			end
		end
	end


	### Returns true if the given +request+'s headers indicate that the local copy
	### of the data corresponding to the specified +uuid+ are cached remotely, and
	### the client can just use the cached version. This usually means that the
	### handler will send a 304 NOT MODIFIED.
	def can_send_cached_response?( request, uuid )
		params = request.params
		moddate_checked = false
		self.log.debug( "Checking to see if we can send a cached response (%p)" % [params] )
		
		# Check If-Modified-Since header
		if (( moddatestr = params['HTTP_IF_MODIFIED_SINCE'] ))
			moddate = Time.parse( moddatestr )
			self.log.debug "Comparing modification dates (%p vs. %p)" %
				[ @metastore[ uuid ].modified, moddate ]
			return true if @metastore[ uuid ].modified <= moddate
			moddate_checked = true
		end
			
		# Check If-None-Match header
		if (( etagheader = params['HTTP_IF_NONE_MATCH'] ))
			self.log.debug "Testing etags (%p) against resource %s" % [ etagheader, uuid ]

			if etagheader =~ /^\s*['"]?\*['"]?\s*$/

				# If we've already check the modification data and our copy is newer
				# RFC 2616 14.26: "[...] if "*" is given and any current entity exists
				# for that resource, then the server MUST NOT perform the requested
				# method, unless required to do so because the resource's modification
				# date fails to match that supplied in an If-Modified-Since header
				# field in the request"
				if moddate_checked
					self.log.debug "Cache miss: wildcard If-None-Match, but " +
						"If-Modified-Since is out of date"
					return false
				end

 				self.log.debug "Cache hit: wildcard If-None-Match"
				return true
			end
			
			etagheader.scan( ENTITY_TAG_PATTERN ) do |weakflag, tag|
				return true if self.etag_matches_resource?( uuid, weakflag, tag )
			end
		end
			
		self.log.debug "Response wasn't cacheable"
		return false
	end
	

	### Returns true if the given +tag+ (i.e., the 'opaque-tag' part of an ETag from 
	### RFC 2616, section 3.11) matches the checksum of the resource associated with 
	### the specified +uuid+. ThingFish currently doesn't support weak validators, 
	### so if +weakflag+ is set, this method currently always returns false.
	def etag_matches_resource?( uuid, weakflag, tag )

		# Client weak request is allowed, but ignored.
		# (checksumming is always strong)
		if weakflag
			self.log.debug "Cache miss: Weak entity tag"
			return false
		end

		# :TODO: Perhaps cache this if creating the metadata proxy becomes a 
		# performance hit.
		if @metastore[ uuid ].checksum == tag
			self.log.debug "Cache hit: Etag checksum match (%p)" % [tag]
			return true
		else
			self.log.debug "Cache miss: Etag doesn't match (%p)" % [tag]
		end
	end
	
	
	
	### Add cache control headers to the given +response+ for the specified +uuid+.
	def add_cache_headers( response, uuid )
		self.log.debug "Adding cache headers to response for %s" % [uuid]
		
		response.header[ 'ETag' ] = %q{"%s"} % [@metastore[ uuid ].checksum]
		response.header[ 'Expires' ] = 1.year.from_now.httpdate
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
