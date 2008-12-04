#!/usr/bin/ruby
#
# ThingFish::ConnectionManager --
#
#
# == Synopsis
#
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

#

require 'timeout'

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/request'
require 'thingfish/response'

### Request wrapper class
class ThingFish::ConnectionManager
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns,
			ThingFish::HtmlInspectableObject,
			ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The subdirectory to search for error templates
	ERROR_TEMPLATE_DIR = Pathname.new( 'errors' )
	
	# The default number of pipelined requests to handle before closing the
	# connection.
	DEFAULT_PIPELINE_MAX = 100
	
	# The default number of seconds to wait for IO before closing the connection.
	DEFAULT_TIMEOUT = 30
	
	# The maximum number of bytes an entity body can be before it's spooled to disk
	# instead of kept in memory
	DEFAULT_MEMORY_BODYSIZE_MAX = 100.kilobytes


	### Create a new ThingFish::ConnectionManager
	def initialize( socket, config, &dispatch_callback )
		@socket            = socket
		@config            = config
		@dispatch_callback = dispatch_callback
		@request_count     = 0
		
		@resource_dir        = @config.resource_dir
		@pipeline_max        = @config.pipeline_max || DEFAULT_PIPELINE_MAX
		@bufsize             = @config.bufsize || DEFAULT_BUFSIZE
		@spooldir            = @config.spooldir_path
		@memory_bodysize_max = @config.memory_bodysize_max || DEFAULT_MEMORY_BODYSIZE_MAX
		@timeout             = @config.connection_timeout || DEFAULT_TIMEOUT

		@read_buffer = ''
	end


	######
	public
	######

	# The buffer for data read from the socket
	attr_reader :read_buffer

	# The maximum number of remaining pipelined requests the manager will handle
	attr_reader :pipeline_max

	# The managed socket
	attr_reader :socket
	
	# The number of requests this connection has handled
	attr_reader :request_count


	### Given the +awesome+, do !!!!!!!


	### Return a human-readable representation of the object
	def inspect
		return "#<%s:0x%x %s>" % [
			self.class.name,
			self.object_id * 2,
			self.session_info
		]
	end


	### Return human-readable information about the current session.
	def session_info
		return "%s (%d/%d requests)" % [
			self.peer_info,
			self.request_count,
			self.pipeline_max,
		]
	end


	### Return human-readable information about the connection's socket
	def peer_info
		return "%s:%d" % [
			self.socket.peeraddr[3],
			self.socket.peeraddr[1],
		]
	end


	### Read data from the socket when it becomes readable.
	### :TODO: Chunked transfer-encoding
	### :TODO: Try nonblocking sysread/write instead of using the Timeout library
	def process
		done = false
		@read_buffer = ''

		until done
			@request_count += 1
			self.log.debug "%s: Servicing request %d" % [ self.peer_info, @request_count ]

			request  = self.read_request
			response = self.dispatch_request( request )
			self.write_response( response, request )

			done = @request_count >= @config.pipeline_max ||
				   !(request.keepalive? && response.keepalive?)
			self.log.debug "%s: Connection will %sstay alive" %
				[ self.session_info, done ? "not " : "" ]
		end

		self.log.debug "%s: close" % [ self.session_info ]

	rescue Errno, IOError => err
		self.log.error "%s: Error in connection" % [ self.session_info ]
		# TODO: handle ECONNRESET, EINTR, EPIPE
	rescue Timeout::Error => err
		self.log.error "%s: timeout %s" % [ self.session_info, err.message ]
	ensure
		@socket.close
	end


	### Read a ThingFish::Request from the socket and return it.
	def read_request
		until pos = @read_buffer.index( BLANK_LINE )
			Timeout.timeout( @timeout ) do
				@read_buffer << @socket.sysread( @bufsize )
				self.log.debug "Read buffer now has %d bytes." % [ @read_buffer.length ]
			end
		end

		headerdata = @read_buffer.slice!( 0, pos + BLANK_LINE.length )
		request = ThingFish::Request.parse( headerdata, @config, @socket )

		# Add a body to the request if it's got a entity-body and it's not
		# a shallow HTTP method
		request.body = self.read_request_body( request )

		return request
	rescue Timeout::Error => err
		raise err.exception( "while reading" )
	end


	### Read the given +request+'s body (if any) from the socket.
	def read_request_body( request )
		body_length = request.header[:content_length].to_i

		# RFC tends to be vague, but we aren't wasting cycles on body data
		# that we would just discard after the fact.
		return nil unless body_length && body_length.nonzero?
		raise ThingFish::RequestError,
			"%s method should not have an entity-body" % [ request.http_method ] if
			HTTP::SHALLOW_METHODS.include?( request.http_method )

		# Choose a body object based on content-length of the entity body
		body = nil
		if body_length >= @memory_bodysize_max
			body = Tempfile.new( 'requestdata', @spooldir.to_s )
			self.log.debug "Spooling request body to tempfile: %s" % [ body.path ]
		else
			body = StringIO.new
			self.log.debug "Keeping request body in memory (%d bytes)" % [ body_length ]
		end

		# Read data from the socket to fill the body
		until body.tell == body_length
			cur_pos = body.tell
			needed  = body_length - cur_pos

			Timeout.timeout( @timeout ) do
				@read_buffer << @socket.sysread( @bufsize ) unless @read_buffer.length >= needed
			end

			until @read_buffer.empty? || needed <= 0
				bytes = body.write( @read_buffer[0, needed] )
				needed -= bytes
				@read_buffer.slice!( 0, bytes )
			end
		end

		body.rewind
		return body
	end


	### Write the +response+ (a ThingFish::Response) for the given +request+ (a ThingFish::Request)
	### to the socket.
	def write_response( response, request )
		buffer = response.status_line + EOL +
		         response.header_data + EOL
		self.log.debug "Response buffer is: %p" % [ buffer ]

		# Make the response body an IOish object if it isn't already
		# and the request actually wants to see a body.
		body = if request.http_method == :HEAD
		 	   nil
		       elsif response.body.respond_to?( :eof? )
		       	   response.body
		       else
		       	   StringIO.new( response.body.to_s )
		       end

		# Write stuff in the buffer to the socket
		until buffer.empty? && (body.nil? || body.eof?)
			buffer << body.read( @bufsize ) if
				buffer.length < @bufsize && !( body.nil? || body.eof? )

			until buffer.empty?
				bytes = Timeout.timeout( @config.connection_timeout ) do
					@socket.syswrite( buffer )
				end
				buffer.slice!( 0, bytes )
			end
		end
	end


	### Call the dispatch callback with the request, then start writing the response when it
	### is returned.
	def dispatch_request( request )
		self.log.debug "Dispatching request"

		# Dispatch the request to the daemon via the callback it gave us
		response = @dispatch_callback.call( request )

		# Handle NOT_FOUND
		unless response.is_handled?
			self.log.info "Preparing NOT FOUND response for unhandled %s to %s" %
				[ request.http_method.to_s, request.uri.to_s ]
			return self.prepare_error_response( response, request, HTTP::NOT_FOUND )
		end

		self.log.debug "Got %s response" % [ response.status_line ]

		# Check to be sure we're providing a response which is acceptable to the client
		unless response.body.nil? || ! response.status_is_successful?
			unless response.content_type
				self.log.warn "Response body set without a content type, using %p." %
					[ DEFAULT_CONTENT_TYPE ]
				response.content_type = DEFAULT_CONTENT_TYPE
			end
			self.log.debug "Checking for acceptable mimetype in response"

			unless request.accepts?( response.content_type )
				self.log.info "Can't create an acceptable response: " +
					"Client accepts:\n  %p\nbut response is:\n  %p" %
					[ request.accepted_types, response.content_type ]
				return self.prepare_error_response( response, request, HTTP::NOT_ACCEPTABLE )
			end
		end

		# Normal response
		return response

	rescue ThingFish::RequestError => err
		response ||= ThingFish::Response.new( request.http_version, @config )
		return self.prepare_error_response( response, request, err.status, err )

	rescue Exception => err
		# Re-raise if it looks like a MockExpectationError
		if err.class.name =~ /MockExpectation/
			raise err
		end

		response ||= ThingFish::Response.new( request.http_version, @config )
		return self.prepare_error_response( response, request, HTTP::SERVER_ERROR, err )
	end


	### Reset the given +response+ and change it to an error response for the given
	### HTTP +statuscode+, append it to the write buffer, and enable write events. If
	### the optional +exception+ object is provided, also output a stacktrace from it.
	def prepare_error_response( response, request, statuscode, exception=nil )
		errtrace = debugtrace = ''

		if exception
			errtrace = "%s while running %s: %s" % [
				exception.class.name,
				response.handlers.last,
				exception.message,
			]
			self.log.error( errtrace )

			debugtrace = "Handlers were:\n  %s\nBacktrace:  %s" % [
				response.handlers.collect {|h| h.class.name }.join("\n  "),
				exception.backtrace.join("\n  ")
			]
			self.log.debug( debugtrace )
		end

		self.log.debug "Preparing error response (%p)" % [ statuscode ]
		response.reset
		response.status = statuscode

		# Build a pretty response if the client groks HTML
		if request.accepts?( CONFIGURED_HTML_MIMETYPE )
			template = self.get_error_response_template( statuscode ) or
				raise "Can't find an error template"
			content = [ template.result( binding() ) ]

			response.data[:tagline] = 'Oh, crap!'
			response.data[:title] = "#{HTTP::STATUS_NAME[statuscode]} (#{statuscode})"
			response.content_type = CONFIGURED_HTML_MIMETYPE

			wrapper = self.get_erb_resource( 'template.rhtml' )

			response.body = wrapper.result( binding() )
		else
			response.content_type = 'text/plain'
			response.body = "%d (%s)" % [ statuscode, HTTP::STATUS_NAME[statuscode] ]
			response.body  << "\n\n" <<
				errtrace   << "\n\n" <<
				debugtrace << "\n\n"
		end

		return response
	end


	### Look for an error response template for the given status code in a directory
	### called 'errors', trying the most-specific code first, then one for the
	### 100-level code, then falling back to a template called 'generic.rhtml'.
	def get_error_response_template( statuscode )
		templates = [
			ERROR_TEMPLATE_DIR + "%d.rhtml" % [statuscode],
			ERROR_TEMPLATE_DIR + "%d.rhtml" % [(statuscode / 100).ceil * 100],
			ERROR_TEMPLATE_DIR + 'generic.rhtml',
		]

		templates.each do |tmpl|
			self.log.debug "Trying to find error template %p" % [tmpl]
			next unless self.resource_exists?( tmpl.to_s )
			return self.get_erb_resource( tmpl.to_s )
		end

		return nil
	end




end # ThingFish::ConnectionManager

# vim: set nosta noet ts=4 sw=4:
