#!/usr/bin/ruby

require 'socket'
require 'uuidtools'
require 'logger'
require 'sync'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/config'
require 'thingfish/connectionmanager'
require 'thingfish/exceptions'
require 'thingfish/mixins'
require 'thingfish/filestore'
require 'thingfish/metastore'
require 'thingfish/handler'
require 'thingfish/request'
require 'thingfish/response'


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
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::Daemon
	include ThingFish::Constants,
		ThingFish::Loggable,
		ThingFish::Daemonizable,
		ThingFish::ResourceLoader,
		ThingFish::HtmlInspectableObject

	### An exception class for signalling daemon threads that they need to shut down
	class Shutdown < Exception; end

	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Parse the command line arguments and return an options struct
	def self::parse_args( args )
		require 'optparse'

		progname = Pathname.new( $0 )
		opts = self.get_default_options

		oparser = OptionParser.new do |oparser|
			oparser.accept( Pathname ) {|path| Pathname(path) }

			oparser.banner = "Usage: #{progname.basename} OPTIONS"

			oparser.separator ''
			oparser.separator 'Daemon Options:'

			oparser.on( '--config-file=STRING', '-f STRING', Pathname,
				"Specify a config file to use." ) do |cfg|
				opts.configfile = cfg
			end

			oparser.separator ''
			oparser.separator 'Other Options:'

			oparser.on_tail( '--help', '-h', FalseClass, "Display this help." ) do
				$stderr.puts oparser
				exit!
	        end

			# Another typical switch to print the version.
			oparser.on_tail( "--version", "Show ThingFish version" ) do
				$stderr.puts ThingFish.version_string( true )
				exit!
			end
		end

		oparser.parse!

		return opts
	end


	### Get the options struct filled with defaults
	def self::get_default_options
		require 'ostruct'
		options = OpenStruct.new
		return options
	end


	### Create an instance, configure it with command line +args+, and start it.
	def self::run( args )
		options = self.parse_args( args )
		config = if options.configfile
		         	ThingFish::Config.load( options.configfile )
		         else
		         	ThingFish::Config.new
		         end

		ThingFish::Daemon.new( config ).start
	end



	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ThingFish daemon object that will listen on the specified +ip+
	### and +port+.
	def initialize( config=nil )
		@config = config || ThingFish::Config.new
		@config.install
		@running = false

		# Load the profiler library if profiling is enabled
		@mutex = Sync.new
		@have_profiling      = false
		@profile_connections = false
		if @config.profiling.enabled?
			@have_profiling = self.load_profiler
			if @config.profiling.connection_enabled?
				@profile_connections = true
				self.log.info "Enabled connection profiling for connections from localhost"
			end
		end

		# Load plugins for filestore, metastore, filters, and handlers
		@config.setup_data_directories
		@filestore = @config.create_configured_filestore
		@metastore = @config.create_configured_metastore
		@filters   = @config.create_configured_filters
		@urimap    = @config.create_configured_urimap

		# Run handler startup actions
		@urimap.handlers.each do |handler|
			self.log.debug "  starting %p" % [ handler ]
			handler.on_startup( self )
		end

		@connection_threads = ThreadGroup.new
		@supervisor = nil

		@listener = TCPServer.new( @config.ip, @config.port )
		@listener.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )
		@listener_thread = nil
	end


	######
	public
	######

	# URI to handler mapping object
	attr_reader :urimap

	# Flag that indicates whether the server is running
	attr_reader :running

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

	# The listener socket
	attr_reader :listener

	# Boolean for testing if profiling is available
	attr_reader :have_profiling

	# A hash of active ConnectionManagers, keyed by the client socket they are managing
	attr_reader :connections

	# The thread which is responsible for cleanup of connection threads
	attr_reader :supervisor


	### Start the server.
	def start
		self.log.info "Starting at: http://%s:%d/" % [ @config.ip, @config.port ]

		daemonize( @config.pidfile ) if @config.daemon
		become_user( @config.user )  if Process.euid.zero? and ! @config.user.nil?

		# Do any storage preparation tasks that may be required after dropping privileges.
		@filestore.on_startup
		@metastore.on_startup

		Signal.trap( "INT" )  { self.shutdown("Interrupted") }
		Signal.trap( "TERM" ) { self.shutdown("Terminated")  }

		@running = true
		self.start_supervisor_thread
		self.start_listener.join
	end


	### Start the thread responsible for handling incoming connections. Returns the new Thread
	### object.
	def start_listener
		@listener_thread = Thread.new do
			Thread.current.abort_on_exception = true
			self.log.debug "Entering listen loop"

			begin
				while @running
					begin
						# use nonblocking accept so closing the socket causes the block to finish 
						socket = @listener.accept_nonblock
						self.handle_connection( socket )
					rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
						self.log.debug "No connections pending; waiting for listener to become readable."
						IO.select([ @listener ])
						next
					rescue IOError => err
						@running = false
						self.log.info "Listener got a %s: exiting accept loop" % [ err.class.name ]
					end
				end
			rescue Shutdown
				self.log.info "Got the shutdown signal."
			ensure
				@running = false
				@listener.close
			end

			self.log.debug "Exited listen loop"
		end

		self.log.debug "Listener thread is: %p" % [ @listener_thread ]
		return @listener_thread
	rescue Spec::Mocks::MockExpectationError
		# Re-raise expectation failures while testing
		raise
	rescue Exception => err
		self.log.error "Unhandled %s: %s" % [ err.class.name, err.message ]
		self.log.debug "  %s" % [ err.backtrace.join("\n  ") ]
	end


	### Start a thread that monitors connection threads and cleans them up when they're done.
	def start_supervisor_thread
		self.log.info "Starting supervisor thread"

		# TODO: work crew thread collection
		@supervisor = Thread.new do
			Thread.current.abort_on_exception = true
			while @running || ! @connection_threads.list.empty?
				@connection_threads.list.find_all {|t| ! t.alive? }.each do |t|
					self.log.debug "Finishing up connection thread %p" % [ t ]
					t.join
				end
				sleep 0.5
			end

			self.log.info "Supervisor thread exiting"
		end

		self.log.debug "Supervisor thread is running (%p)" % [ @supervisor ]
	end


	### Handle an incoming connection on the given +socket+.
	def handle_connection( socket )
		connection = ThingFish::ConnectionManager.new( socket, @config, &self.method(:dispatch) )
		self.log.info "Connect: %s (%p)" % 
			[ connection.session_info, Thread.current ]

		t = Thread.new do
			Thread.current.abort_on_exception = true
			begin
				if @profile_connections && socket.peeraddr[3] == '127.0.0.1'
					self.profile( "connection" ) do
						connection.process
					end
				else
					connection.process
				end
			rescue Shutdown
				self.log.info "Forceful shutdown of connection thread %p." % [ Thread.current ]
			end
			self.log.debug "Connection thread %p done." % [ Thread.current ]
		end

		@connection_threads.add( t )
	rescue ::RuntimeError => err
		self.log.error "Fatal %s in connection thread for %p: %s\n  " % [
			err.class.name,
			connection,
			err.message,
			err.backtrace.join( "\n  " )
		]
	end


	### Shut the server down gracefully, outputting the specified +reason+ for the
	### shutdown to the logs.
	def shutdown( reason="no reason", force=false )
		if @running
			@running = false
		else
			force = true
		end

		self.log.info "Shutting down %p from %p" % [ @listener_thread, Thread.current ]
		@listener_thread.raise( Shutdown ) if ! @listener_thread.nil? && @listener_thread.alive?

		if force
			self.log.warn "Forceful shutdown. Terminating %d active connection threads." %
				[ @connection_threads.list.length ]
			self.log.debug "  Active threads: %p" % [ @connection_threads.list ]

			@connection_threads.list.each do |t|
				t.raise( Shutdown )
			end
		else
			self.log.warn "Graceful shutdown. Waiting on %d active connection threads." %
				[ @connection_threads.list.length ]
			self.log.debug "  Active threads: %p" % [ @connection_threads.list ]
		end

		@supervisor.join
	end


	### Returns a Hash of handler information of the form:
	### {
	###    '<handlerclass>' => ['<installed uris>']
	### }
	def handler_info
		info = {}

		self.urimap.map.each do |uri,handlers|
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
		uuid ||= UUIDTools::UUID.timestamp_create

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
		begin
			@metastore.transaction do
				now = Time.now.gmtime
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
		rescue => err
			self.log.error "Error saving resource to metastore: %s" % [ err.message ]
			@filestore.delete( uuid ) if new_resource
			raise
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


	### Remove any resources that have a +related_to+ of the given UUID, and
	### the given +relation+ (or any relation if none is specified)
	### :TODO: Purge recursively?
	def purge_related_resources( uuid, relation=nil )
		results = @metastore.find_by_exact_properties( :related_to => uuid.to_s, :relation => relation )
		self.log.debug "Found %d UUIDS for purging" % [ results.length ]

		results.each do |subuuid,_|
			self.log.debug "purging appended resource %s for %s" % [ subuuid, uuid ]
			@metastore.delete_resource( subuuid )
			@filestore.delete( subuuid )
		end
	end


	# SMITH YOU!


	### Dispatch the +request+ to filters and handlers and return a ThingFish::Response.
	def dispatch( request )
		response = ThingFish::Response.new( request.http_version, @config )

		self.profile_request( request, response ) do

			# Let the filters manhandle the request
			self.filter_request( request, response )

			# Now execute the given handlers on the request and response
			self.run_handlers( request, response ) unless response.is_handled?

			# Let the filters manhandle the response
			self.filter_response( response, request )
		end

		return response
	end


	### Start a profile for the provided +block+ if profiling is enabled for the 
	### specified +request+.
	def profile_request( request, response, &block )
		if self.have_profiling and request.run_profile?
			description = request.uri.path.gsub( %r{/}, '_' ).sub( /^_/, '' ).chomp('_')
			self.profile( description, &block )
		else
			yield
		end
	end


	### Start a profile for the provided +block+ if profiling is enabled, dumping the result
	### out to a profile directory afterwards.
	def profile( description, &block )
		if self.have_profiling
			result = nil

			@mutex.synchronize( Sync::EX ) do
				result = RubyProf.profile( &block )
			end

			self.log.debug {
				output = ""
				printer = RubyProf::FlatPrinter.new( result )
				printer.print( output, 0 )
				output
			}

			filename = @config.profiledir_path + "%f#%x#%s" % [
				Time.now,
				Thread.current.object_id * 2,
				description
			]
			File.open( "#{filename}.html", 'w' ) do | profile |
				printer = RubyProf::GraphHtmlPrinter.new( result )
				printer.print( profile )
				# profile.print( Marshal.dump([ request, result ]) )  # TODO!!
			end
		else
			yield
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

		self.log.info "Enabled profiling"
		return true

	rescue Exception => err
		self.log.error "Couldn't load profiler: %s" % [ err.message ]
		self.log.debug( err.backtrace.join("\n") )
		return false
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

			# Allow filters to interrupt the dispatch; auth filter
			# uses this to deny the request before incurring the cost of
			# all the filters that may come behind it. Auth adds identity
			# information to the request (and so acts like other filters),
			# whereas authorization acts on a request based on the
			# added identity information (and so is a handler).
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


	### Iterate through the handlers for this URI and execute each one. Stop
	### executing handlers as soon as the response's status changes.
	def run_handlers( request, response )
		delegators, processor = @urimap.resolve( request.uri )
		self.log.debug "Dispatching to %s via %d delegators" %
			[ processor.class.name, delegators.length ]

		return self.run_handler_chain( request, response, delegators, processor )
	end


	### Recursively delegate the given +request+ and +response+ to the
	### specified +delegators+.  Once +delegators+ is empty, run the
	### +processor+ for the current request.
	def run_handler_chain( request, response, delegators, processor )

		request.check_body_ios

		# If there aren't any delegators left to run through, run the processor
		if delegators.empty?
			response.handlers << processor
			return processor.process( request, response )
		else
			delegator = delegators.first
			response.handlers << delegator
			next_delegators = delegators[ 1..-1 ]

			self.log.debug "Delegating to %s" % [ delegator.class.name ]
			return delegator.delegate( request, response ) do |dreq, dres|
				self.run_handler_chain( dreq, dres, next_delegators, processor )
			end
		end
	end

end # class ThingFish::Daemon

# vim: set nosta noet ts=4 sw=4:
