#!/usr/bin/ruby
#
# ThingFish daemon class
#
# == Synopsis
#
#   require 'thingfish/daemon'
#   require 'thingfish/config'
#
#   config = ThingFish::Config.load( "thingfish.conf" )
#   server = ThingFish::Daemon.new( config )
#   
#   accepter = server.run  # => #<Thread:0x142317c sleep>
#   
#   Signal.trap( "INT" ) { server.shutdown("Interrupted") }
#   Signal.trap( "TERM" ) { server.shutdown("Terminated") }
# 
#   accepter.join
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
require 'mongrel'
require 'uuidtools'
require 'etc'
require 'logger'

require 'monkeypatches'

require 'thingfish/constants'
require 'thingfish/config'
require 'thingfish/exceptions'
require 'thingfish/mixins'
require 'thingfish/filestore'
require 'thingfish/metastore'
require 'thingfish/handler'
require 'thingfish/request'
require 'thingfish/response'


### ThingFish daemon class
class ThingFish::Daemon < Mongrel::HttpServer
	include ThingFish::Constants,
		ThingFish::Loggable,
		ThingFish::ResourceLoader

	# The subversion ID
	SVNId = %q$Id$
	
	# The SVN revision number
	SVNRev = %q$Rev$

	# Options for the default handler
	DEFAULT_HANDLER_OPTIONS = {}
	
	# The subdirectory to search for error templates
	ERROR_TEMPLATE_DIR = Pathname.new( 'errors' )


	### Create a new ThingFish daemon object that will listen on the specified +ip+
	### and +port+.
	def initialize( config=nil )
		@config = config || ThingFish::Config.new
		@config.install

		# Load plugins for filestore, filters, and handlers
		@filestore = @config.create_configured_filestore
		@metastore = @config.create_configured_metastore
		@filters = @config.create_configured_filters

		super( @config.ip, @config.port )
		self.log.info "Starting at: http://%s:%d/" % [ @config.ip, @config.port ]

		# Register all the handlers
		self.register( "/", self.create_default_handler(@config) )
		@config.each_handler_uri do |handler, uri|
			self.log.info "  registering %s at %p" % [handler.class.name, uri]
			self.register( uri, handler, handler.options['in_front'] )
		end
		
		@resource_dir = @config.defaulthandler.resource_dir
		
		self.log.debug {
			"Handler map is:\n    " + 
			self.classifier.handler_map.collect {|uri, handlers|
				"%s: [%s]" % [ uri, handlers.collect{|h| h.class.name}.join(", ") ]
			}.join( "\n    ")
		}
	end

	######
	public
	######

	# The ThingFish::FileStore instance that acts as the interface to the file storage
	# mechanism used by the daemon.
	attr_reader	:filestore

	# The ThingFish::MetaStore instance that acts as the interface to the metadata
	# mechanism used by the daemon.
	attr_reader :metastore

	# The ThingFish::Config instance that contains all current configuration
	# information used by the daemon.
	attr_reader :config
	
	# The Array of installed ThingFish::Filters
	attr_reader :filters


	### Perform any additional daemon actions before actually starting
	### the Mongrel side of things.
	def run

		# Become a daemon, doing all the things a good daemon does.
		# TODO:  Not sure how to adequately test anything involving fork()...
		if @config.daemon

			if ! @config.pidfile.nil? && File.exists?( @config.pidfile )
				self.log.warn "Stale pidfile found (%s)" % [ @config.pidfile ]
			end

			self.log.info "Detaching from terminal and daemonizing..."
			fork and exit
			Process.setsid

			if ( pid = fork )
				# parent, write pidfile if required
				unless @config.pidfile.nil?
					File.open( @config.pidfile, 'w' ) do |pidfile|
						pidfile.puts pid
					end
				end
				exit
			end

			Dir.chdir('/')
			File.umask(0)
			[ $stdin, $stdout, $stderr ].each { |io| io.send( :reopen, '/dev/null' ) }
		end

		# Drop privileges if we're root, and we're configged to do so.
		if Process.euid.zero? and ! @config.user.nil?
			self.log.debug "Dropping privileges (user: %s)" % @config.user
			Process.euid = Etc.getpwnam( @config.user ).uid
		end

		super
	end


	### Shut the server down gracefully, outputting the specified +reason+ for the
	### shutdown to the logs.
	def shutdown( reason="no reason" )
		self.log.warn "Shutting down: #{reason}"
		self.stop
	end


	### Store the data from the uploaded entity +body+ in the filestore; 
	### create/update any associated metadata.
	def store_resource( body, body_metadata, uuid=nil )
		new_resource = uuid.nil?
		uuid ||= UUID.timestamp_create

		# :BRANCH: Deletes new resources if there's an error while storing
		# :BRANCH: Doesn't delete it if it's an update
		# Store the data, catching and cleaning up on error
		begin
			checksum = @filestore.store_io( uuid, body )
		rescue => err
			self.log.error "Error saving resource to filestore: %s" % [ err.message ]
			@filestore.delete( uuid ) if new_resource
			raise
		end

		# Store some default metadata about the resource
		now = Time.now
		metadata = @metastore[ uuid ]
		metadata.update( body_metadata )

		# :BRANCH: Won't overwrite an existing creation date
		metadata.checksum = checksum
		metadata.created  = now unless metadata.created
		metadata.modified = now

		self.log.info "Created new resource %s (%s, %0.2f KB), checksum is %s" % [
			uuid,
			metadata.content_type,
			Integer(metadata.content_length) / 1024.0,
			metadata.checksum
		  ]
		
		return uuid
	end
	

	#########
	protected
	#########

	### Override Mongrel's handler-processing to incorporate filters, and our own 
	### request and response objects.
	def dispatch_to_handlers( client, handlers, mongrel_request, mongrel_response )
		request  = ThingFish::Request.new( mongrel_request, @config )
		response = ThingFish::Response.new( mongrel_response )

		begin
			# Let the filters manhandle the request
			self.filter_request( request, response )

			# Now execute the given handlers on the request and response
			self.run_handlers( client, handlers, request, response ) unless
				response.is_handled?

			# Let the filters manhandle the response
			self.filter_response( response, request )

			# Handle NOT_FOUND 
			return self.send_error_response( response, request, HTTP::NOT_FOUND, client ) \
				unless response.is_handled?

			# Normal response
			self.send_response( response ) unless client.closed?

		rescue ThingFish::RequestError => err
			self.send_error_response( response, request, err.status, client, err )

		rescue => err
			self.send_error_response( response, request, HTTP::SERVER_ERROR, client, err )
		end
	end
	

	### Filter and potentially modify the incoming request.
	def filter_request( request, response )
		@filters.each do |filter|
			response.filters << filter
			filter.handle_request( request, response )
			break if response.status != ThingFish::Response::DEFAULT_STATUS
		end
	end


	### Filter (and potentially modify) the outgoing response with the filters
	### that were registered with it during the request-filtering stage
	def filter_response( response, request )
		response.filters.reverse.each do |filter|
			filter.handle_response( response, request )
		end
	end
	

	### Handle errors in a consistent fashion.  Log and output to the client.
	def send_error_response( response, request, statuscode, client, err=nil )
		errtrace = debugtrace = ''

		if err
			errtrace = "Error while running %s: %s" % [
				response.handlers.last,
				err.message,
			]
			self.log.error( errtrace )

			debugtrace = "Handlers were:\n  %s\nBacktrace:  %s" % [
				response.handlers.collect {|h| h.class.name }.join("\n  "),
				err.backtrace.join("\n  ")
			]
			self.log.debug( debugtrace )
		end

		response.reset
		response.status = statuscode

		# Build a pretty response if the client groks HTML
		if request.accepts?( 'text/html' )
			template = self.get_error_response_template( statuscode ) or
				raise "Can't find an error template"
			
			response.headers[ :content_type ] = 'text/html'
			response.body = template.result( binding() )
		else
			response.headers[ :content_type ] = 'text/plain'
			response.body = "%d (%s)" % [ statuscode, HTTP::STATUS_NAME[statuscode] ]
			response.body << "\n\n" << 
				errtrace << "\n\n" <<
				debugtrace << "\n\n"
		end

		self.send_response( response ) unless client.closed?
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

	
	### Iterate through the handlers for this URI and execute each one. Stop 
	### executing handlers as soon as the response's status changes.
	def run_handlers( client, handlers, request, response )
		self.log.debug "Dispatching to %d handlers" % [handlers.length]

		# BRANCH: Iterate through handlers
		handlers.each do |handler|
			# BRANCH: Adds handlers to the response as it executes them
			response.handlers << handler
			handler.process( request, response )
			# BRANCH: Stops running handlers on status change
			# BRANCH: Stops running handlers if client connection closes
			break if response.status != ThingFish::Response::DEFAULT_STATUS ||
				client.closed?
		end
	end
	

	### Send the response on the socket, doing a buffered send if the response's 
	### body responds to :read, or just writing it to the socket if not.
	def send_response( response )
		body = response.body

		# Send the status line
		status_line = STATUS_LINE_FORMAT %
			[ response.status, HTTP::STATUS_NAME[ response.status ] ]
		response.write( status_line )
		self.log.info "Response: #{status_line.chomp}"

		# Send the headers
		response.headers[:connection] = 'close'
		response.headers[:content_length] ||= response.get_content_length
		response.headers[:date] = Time.now.httpdate
		response.write( response.headers.to_s + "\r\n" )

		# Send the buffered entity body
		if body.respond_to?( :read )
			buf     = ''
			bufsize = @config.bufsize

			while body.read( bufsize, buf )
				until buf.empty?
					bytes = response.write( buf )
					buf.slice!( 0, bytes )
				end
			end
		else
			# Send unbuffered -- body already in memory.
			response.write( body.to_s )
		end
		
		response.done = true
	end


	### Create an instance of the default handler, with options dictated by the
	### specified +config+ object.
	def create_default_handler( config )
		options = DEFAULT_HANDLER_OPTIONS.dup
		if config.defaulthandler
			options.merge!( config.defaulthandler )
		end
		
		return ThingFish::Handler.create( 'default', options )
	end

end # class ThingFish::Daemon

# vim: set nosta noet ts=4 sw=4:
