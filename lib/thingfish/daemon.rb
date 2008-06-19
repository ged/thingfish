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

begin
	require 'thingfish'
	require 'mongrel'
	require 'uuidtools'
	require 'logger'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


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
		ThingFish::ResourceLoader,
		ThingFish::Daemonizable,
		ThingFish::HtmlInspectableObject

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

		# Load the profiler library if profiling is enabled
		@have_profiling = false
		if @config.profiling.enabled?
			@have_profiling = self.load_profiler
		end
		
		# Load plugins for filestore, filters, and handlers
		@config.setup_data_directories
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

	# Boolean for testing if profiling is available
	attr_reader :have_profiling
	
	
	### Perform any additional daemon actions before actually starting
	### the Mongrel side of things.
	def run
		daemonize( @config.pidfile ) if @config.daemon
		become_user( @config.user )  if Process.euid.zero? and ! @config.user.nil?
		
		# Do any storage preparation tasks that may be required after dropping privileges.
		@filestore.startup
		@metastore.startup
		
		super
	end


	### Shut the server down gracefully, outputting the specified +reason+ for the
	### shutdown to the logs.
	def shutdown( reason="no reason" )
		self.log.warn "Shutting down: #{reason}"
		self.stop
	end


	### Returns a Hash of handler information of the form:
	### {
	###    '<handlerclass>' => ['<installed uris>']
	### }
	def handler_info
		info = {}

		self.classifier.handler_map.each do |uri,handlers|
			handlers.each do |h|
				info[ h.plugin_name ] ||= []
				info[ h.plugin_name ] << uri
			end
		end
		
		return info
	end
	

	### Returns a Hash of filter information of the form:
	### {
	###    '<filterclass>' => [<version info>]
	### }
	def filter_info
		info = {}
	
		self.filters.each do |filter|
			info[ filter.class.plugin_name ] = filter.info
		end
		
		return info
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
			body.unlink if body.respond_to?( :unlink )
		rescue => err
			self.log.error "Error saving resource to filestore: %s" % [ err.message ]
			@filestore.delete( uuid ) if new_resource
			raise
		end

		# Store some default metadata about the resource
		@metastore.transaction do
			now = Time.now
			metadata = @metastore[ uuid ]
			metadata.update( body_metadata )

			# :BRANCH: Won't overwrite an existing creation date
			metadata.checksum = checksum
			metadata.created  = now unless metadata.created
			metadata.modified = now

			self.log.info "Created new resource %s (%s, %0.2f KB), checksum is %s" % [
				uuid,
				metadata.format,
				Integer(metadata.extent) / 1024.0,
				metadata.checksum
			  ]
		end
		
		return uuid
	end
	
	
	### Recursively store all resources in the specified +request+ that are related to +body+.
	### Use the specified +uuid+ for the 'related_to' metadata value.
	def store_related_resources( body, uuid, request )
		request.related_resources[ body ].each do |related_resource, related_metadata|
			related_metadata[ :related_to ] = uuid
			metadata = request.metadata[related_resource].merge( related_metadata )

			subuuid = self.store_resource( related_resource, metadata )
			self.store_related_resources( related_resource, subuuid, request )
		end
	rescue => err
		self.log.error "%s while storing related resource: %s" % [ err.class.name, err.message ]
		self.log.debug "Backtrace: %s" % [ err.backtrace.join("\n  ") ]
	end
	
	
	### Remove any resources that have a +related_to+ of the given UUID, and a +relation+ of 
	### 'appended'.
	def purge_related_resources( uuid )
		uuids = @metastore.find_by_exact_properties( :related_to => uuid.to_s, :relation => 'appended' )
		uuids.each do |subuuid|
			self.log.debug "purging appended resource %s for %s" % [ subuuid, uuid ]
			@metastore.delete_resource( subuuid )
			@filestore.delete( subuuid )
		end
	end
	
	

	#########
	protected
	#########

	### Override Mongrel's handler-processing to wrap our own request and 
	### response object around Mongrel's.
	def dispatch( client, handlers, mongrel_request, mongrel_response )
		request  = ThingFish::Request.new( mongrel_request, @config )
		response = ThingFish::Response.new( mongrel_response )
		
		if self.have_profiling and request.run_profile?
			self.log.debug "Profiling the current request"
			self.profile( request, response ) do
				self.dispatch_to_handlers( client, handlers, request, response )
			end
		else
			self.dispatch_to_handlers( client, handlers, request, response )
		end
	end

	
	### Start a profile for the provided +block+ if profiling is enabled, dumping the result
	### out to a profile directory afterwards.
	def profile( request, response, &block )
		result = RubyProf.profile( &block )
		
		self.log.debug {
			output = ""
			printer = RubyProf::FlatPrinter.new( result )
			printer.print( output, 0 )
			output
		}
		
		filename = @config.profiledir_path + "%f#%d#%s" % [
			Time.now,
			Thread.current.object_id * 2,
			request.uri.path.gsub( %r{/}, '_' ).sub( /^_/, '' ).chomp('_')
		]
		File.open( "#{filename}.html", 'w' ) do | profile |
			printer = RubyProf::GraphHtmlPrinter.new( result )
			printer.print( profile )
			# profile.print( Marshal.dump([ request, result ]) )  # TODO!!
		end
	end

	
	### Attempt to load and configure the profiling library. 
	def load_profiler
		require 'ruby-prof'

		# enable additonal optional profile measurements
		mask  = RubyProf::PROCESS_TIME
		mask |= RubyProf::CPU_TIME if 
			@config.profiling.metrics.include?( 'cpu' ) and ! RubyProf::CPU_TIME.nil?		
		mask |= RubyProf::ALLOCATIONS if 
			@config.profiling.metrics.include?( 'allocations' ) and ! RubyProf::ALLOCATIONS.nil?
		mask |= RubyProf::MEMORY if 
			@config.profiling.metrics.include?( 'memory' ) and ! RubyProf::MEMORY.nil?
	 	RubyProf.measure_mode = mask
	
		self.log.debug "Enabled profiling"
		return true
		
	rescue Exception => err
		self.log.error "Couldn't load profiler: %s" % [ err.message ]
		self.log.debug( err.backtrace.join("\n") )
		return false
	end
	

	### Send the request and response through the filters in request mode,
	### run the appropriate handlers, and then send them back through the filters
	### in response mode. Handle any ThingFish::RequestErrors and other exceptions
	### with appropriate HTTP responses.
	def dispatch_to_handlers( client, handlers, request, response )
		
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
				return self.send_error_response( response, request, 
					HTTP::NOT_ACCEPTABLE, client )
			end
		end
		
		# Normal response
		self.send_response( response, request ) unless client.closed?

	rescue ThingFish::RequestError => err
		self.send_error_response( response, request, err.status, client, err )

	rescue Exception => err
		self.send_error_response( response, request, HTTP::SERVER_ERROR, client, err )
	end
	

	### Filter and potentially modify the incoming request.
	def filter_request( request, response )
		@filters.each do |filter|
			# self.log.debug "Passing request through %s" % [ filter.class.name ]
			begin
				filter.handle_request( request, response )
			rescue Exception => err
				self.log.error "Request filter raised a %s: %s" % 
					[ err.class.name, err.message ]
				self.log.debug "  " + err.backtrace.join("\n  ")
			else
				response.filters << filter
			ensure
				request.check_body_ios
			end
			
			break if response.handled?
		end
	end


	### Filter (and potentially modify) the outgoing response with the filters
	### that were registered with it during the request-filtering stage
	def filter_response( response, request )
		response.filters.each do |filter|
			# self.log.debug "Passing response through %s" % [ filter.class.name ]
			begin
				filter.handle_response( response, request )
			rescue Exception => err
				self.log.error "Response filter raised a %s: %s" % 
					[ err.class.name, err.message ]
				self.log.debug "  " + err.backtrace.join("\n  ")
			ensure
				if response.body.respond_to?( :rewind )
					response.body.open if response.body.closed?
					response.body.rewind
				end
			end
		end
	end
	

	### Handle errors in a consistent fashion.  Log and output to the client.
	def send_error_response( response, request, statuscode, client, err=nil )
		errtrace = debugtrace = ''

		if err
			errtrace = "%s while running %s: %s" % [
				err.class.name,
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

		# If the client is already closed, let's not bother creating the
		# response, since there is no client to receive it.
		if client.closed?
			self.log.warn 'Aborting without response: client socket closed'
			return
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
			response.body << "\n\n" << 
				errtrace << "\n\n" <<
				debugtrace << "\n\n"
		end

		self.send_response( response, request ) unless client.closed?
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

		handlers.each do |handler|
			response.handlers << handler
			request.check_body_ios
			handler.process( request, response )
			break if response.is_handled? || client.closed?
		end
	end
	

	### Send the response on the socket, doing a buffered send if the response's 
	### body responds to :read, or just writing it to the socket if not.
	def send_response( response, request )
		body = response.body

		# Send the status line
		status_line = STATUS_LINE_FORMAT %
			[ response.status, HTTP::STATUS_NAME[ response.status ] ]
		self.log.info "Response: %p" % [ status_line ]
		response.write( status_line )

		# Send the headers
		response.headers[:connection] = 'close'
		response.headers[:content_length] ||= response.get_content_length
		response.headers[:date] = Time.now.httpdate
		response.write( response.headers.to_s + "\r\n" )

		# Send the buffered entity body unless the request method is a HEAD
		unless request.http_method == 'HEAD'
			if body.respond_to?( :read )
				self.log.debug "Writing response using buffered IO"
				buf     = ''
				bufsize = @config.bufsize

				while body.read( bufsize, buf )
					until buf.empty?
						bytes = response.write( buf )
						buf.slice!( 0, bytes )
					end
				end

			# Send unbuffered -- body already in memory.
			else
				self.log.debug "Writing response using unbuffered IO"
				response.write( body.to_s )
			end
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
