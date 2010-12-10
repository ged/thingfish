#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'socket'

require 'thingfish'
require 'thingfish/daemon'
require 'thingfish/config'
require 'thingfish/urimap'


include ThingFish::TestConstants

class TestHandler < ThingFish::Handler
end

module RubyProf
	PROCESS_TIME = 1
	CPU_TIME     = 2
	ALLOCATIONS  = 4
	MEMORY       = 8

	class FlatPrinter
		def initialize( *args ); end
		def print( *args ); end
	end
	class GraphHtmlPrinter
		def initialize( *args ); end
		def print( *args ); end
	end
	class Result; end
end



#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Daemon do

	before( :each ) do
		# Have to set up logging each time, 'cause Daemon alters it in some examples
		setup_logging( :fatal )

		# Stop the daemon from actually doing anything in another thread or
		# listening on a real socket.
		@listener = stub( "Server listener socket", :setsockopt => nil )
		TCPServer.stub!( :new ).and_return( @listener )
	end

	# Daemon tests the logger interface, so we reset after each test
	# AND after they're all done.
	after( :each ) do
		ThingFish.reset_logger
	end

	after( :all ) do
		reset_logging()
	end


	### Handler registration

	it "asks its config for a URImap and starts each handler from it" do
		uri = '/cellphone/not/walkietalkie'
		config = mock( "config" ).as_null_object
		urimap = mock( "URI map" )
		handler = mock( "handler" )

		config.profiling.stub!( :enabled? ).and_return( false )

		config.should_receive( :create_configured_urimap ).and_return( urimap )
		urimap.should_receive( :handlers ).and_return( [handler] )
		handler.should_receive( :on_startup ).with( duck_type( :filestore ) )

		ThingFish::Daemon.new( config )
	end


	### End-to-end
	describe " configured with defaults" do

		before( :each ) do
			@config = ThingFish::Config.new
			@config.defaulthandler.resource_dir = 'var/www'
			@daemon = ThingFish::Daemon.new( @config )

			@processor = mock( "processor handler" )
			@handlers = [ [], @processor ]
			@filters = []

			@urimap = mock( "URI to handler map" )
			@urimap.stub!( :resolve ).and_return( @handlers )
			@daemon.instance_variable_set( :@urimap, @urimap )

			@uri = URI.parse( '/' )

			@client = mock( "client socket object" )
			@client.stub!( :peeraddr ).and_return([ Socket::AF_INET, 3474, '127.0.0.1', 'localhost' ])

			@request = mock( "request object" )
			@response = mock( "response object" )

			@request_headers = mock( "mock request headers" )
			@response_headers = mock( "mock response headers" )

			@request.stub!( :headers ).and_return( @request_headers )
			@request.stub!( :http_method ).and_return( :GET )
			@request.stub!( :check_body_ios )
			@request.stub!( :uri ).and_return( @uri )

			@response.stub!( :status ).and_return( nil )
			@response.stub!( :headers ).and_return( @response_headers )
			@response.stub!( :handlers ).and_return( @handlers )
			@response.stub!( :filters ).and_return( @filters )
			@response.stub!( :handled? ).and_return( false )
			@response.stub!( :body ).and_return( "test body" )

			@processor.stub!( :process ).and_return( @request, @response )

			@supervisor_thread = mock( "supervisor thread" )
			@connection_thread = mock( "connection thread" )
			@listener_thread = mock( "listener thread" )
		end


		describe "startup" do

			it "starts its filestore, metastore, and listener thread on startup" do
				Process.should_receive( :euid ).at_least( :once ).and_return( 266 )

				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				filestore.should_receive( :on_startup )
				metastore.should_receive( :on_startup )

				Thread.should_receive( :new ).and_return( @supervisor_thread, @listener_thread )
				@listener_thread.should_receive( :join )

				@daemon.start
			end


			it "the listener thread accepts and creates a ConnectionManager for each incoming connection" do
				conn_threadgroup = mock( "connection threadgroup" )
				@daemon.instance_variable_set( :@connection_threads, conn_threadgroup )
				@daemon.instance_variable_set( :@running, true )
				@daemon.instance_variable_set( :@supervisor, @supervisor_thread )
				@supervisor_thread.stub!( :join )

				Thread.should_receive( :new ).and_yield.
					and_return( @connection_thread, @listener_thread )
				Thread.stub!( :current ).and_return( @connection_thread, @listener_thread )
				@listener_thread.should_receive( :abort_on_exception= ).with( true )
				@connection_thread.should_receive( :abort_on_exception= ).with( true )

				socket = mock( "client socket" )
				@listener.should_receive( :accept_nonblock ).and_return( socket )

				connection = mock( "connection manager" )
				ThingFish::ConnectionManager.should_receive( :new ).
					with( socket, @config ).
					and_return( connection )

				connection.stub!( :session_info )
				connection.should_receive( :process )

				conn_threadgroup.should_receive( :add ).with( @connection_thread ).
					and_return { @daemon.shutdown }

				# For the shutdown call
				@listener.should_receive( :close )
				conn_threadgroup.stub!( :list ).and_return( [] )

				@daemon.start_listener
			end


			it "handles uncaught exceptions raised from inside the connection thread" do
				conn_threadgroup = mock( "connection threadgroup" )
				@daemon.instance_variable_set( :@connection_threads, conn_threadgroup )

				Thread.should_receive( :new ).and_yield.and_return( @connection_thread )
				Thread.stub!( :current ).and_return( @connection_thread )
				@connection_thread.should_receive( :abort_on_exception= ).with( true )

				socket = mock( "client socket" )
				connection = mock( "connection manager" )
				ThingFish::ConnectionManager.should_receive( :new ).
					with( socket, @config ).
					and_return( connection )

				connection.stub!( :session_info )
				connection.should_receive( :process ).
					and_raise( ThingFish::RequestError.new("something went wrong") )

				lambda {
					@daemon.handle_connection( socket )
				}.should_not raise_error()
			end


			it "doesn't block if the listener socket doesn't have an incoming connection" do
				conn_threadgroup = mock( "connection threadgroup" )
				@daemon.instance_variable_set( :@connection_threads, conn_threadgroup )
				@daemon.instance_variable_set( :@running, true )
				@daemon.instance_variable_set( :@supervisor, @supervisor_thread )
				@supervisor_thread.stub!( :join )

				Thread.should_receive( :new ).and_yield.and_return( @listener_thread )
				Thread.stub!( :current ).and_return( @connection_thread, @listener_thread )
				@connection_thread.should_receive( :abort_on_exception= ).with( true )

				socket = mock( "client socket" )
				@listener.should_receive( :accept_nonblock ).and_raise( Errno::EAGAIN )

				ThingFish::ConnectionManager.should_not_receive( :new )

				IO.should_receive( :select ).with([ @listener ]).
					and_return { @daemon.instance_variable_set(:@running, false) }

				# For the shutdown call
				@listener.should_receive( :close )
				conn_threadgroup.stub!( :list ).and_return( [] )

				@daemon.start_listener
			end
		end

		### Handlers
		describe " handler dispatching" do

			it "runs through all of its delegators before running the processor" do
				handler_list = []
				@response.stub!( :handlers ).and_return( handler_list )

				delegator_handler_one = mock( "first delegator handler" )
				delegator_handler_two = mock( "second delegator handler" )

				@handlers.first << delegator_handler_one
				@handlers.first << delegator_handler_two

				delegator_handler_one.should_receive( :delegate ).
					with( @request, @response ).
					and_yield( @request, @response )

				delegator_handler_two.should_receive( :delegate ).
					with( @request, @response ).
					and_yield( @request, @response )

				@processor.should_receive( :process ).
					with( @request, @response ).
					and_return([ @request, @response ])

				@daemon.run_handlers( @request, @response )
			end
		end


		### Filters
		describe " filter processing" do

			it "can gather a hash of metadata about all the filters it has loaded" do
				filter_eins = mock( "request filter number one" )
				filter_zwei = mock( "request filter number two" )
				filter_class = mock( "mock filter class" )

				filter_eins.stub!( :class ).and_return( filter_class )
				filter_zwei.stub!( :class ).and_return( filter_class )

				@daemon.filters << filter_eins << filter_zwei

				filter_class.should_receive( :plugin_name ).and_return( "eins", "zwei" )
				filter_eins.should_receive( :info ).and_return( :eins_info )
				filter_zwei.should_receive( :info ).and_return( :zwei_info )

				info = @daemon.filter_info

				info.should be_an_instance_of( Hash )
				info.should have(3).members
				info.keys.should include( 'ruby', 'eins', 'zwei' )
				info.values.should include( :eins_info, :zwei_info )
			end


			it "iterates through its filters on incoming requests" do
				filter_uno = mock( "request filter number one" ).as_null_object
				filter_dos = mock( "request filter number two" ).as_null_object

				@daemon.filters << filter_uno << filter_dos
				@response.should_receive( :handled? ).
					at_least( :once ).
					and_return( false )

				filter_uno.
					should_receive( :handle_request ).
					once.
					with( @request, @response )
				filter_dos.
					should_receive( :handle_request ).
					once.
					with( @request, @response )

				@daemon.filter_request( @request, @response )
			end


			it "doesn't propagate exceptions raised from request filters" do
				filter_uno = mock( "request filter number one" ).as_null_object
				filter_dos = mock( "request filter number two" ).as_null_object

				@daemon.filters << filter_uno << filter_dos
				@response.should_receive( :handled? ).
					at_least( :once ).
					and_return( false )

				filter_uno.
					should_receive( :handle_request ).
					once.
					with( @request, @response ).
					and_raise( StandardError.new("something went wrong") )
				filter_dos.
					should_receive( :handle_request ).
					once.
					with( @request, @response )

				lambda {
					@daemon.filter_request( @request, @response )
				}.should_not raise_error()
			end


			it "filters the response through all the filters which saw the request" do
				filter_uno  = mock( "request filter number one" ).as_null_object
				filter_dos  = mock( "request filter number two" ).as_null_object
				filter_tres = mock( "request filter number three" ).as_null_object

				@response.should_receive( :filters ).and_return([ filter_uno, filter_dos ])

				filter_uno.
					should_receive( :handle_response ).
					once.
					with( @response, @request )
				filter_dos.
					should_receive( :handle_response).
					once.
					with( @response, @request )
				filter_tres.
					should_not_receive( :handle_response )

				@daemon.filter_response( @response, @request )
			end

			it "doesn't propagate exceptions raised from response filters" do
				filter_uno = mock( "response filter number one" ).as_null_object
				filter_dos = mock( "response filter number two" ).as_null_object

				@response.should_receive( :filters ).and_return([ filter_uno, filter_dos ])

				filter_uno.
					should_receive( :handle_response ).
					once.
					with( @response, @request ).
					and_raise( StandardError.new("something went wrong") )
				filter_dos.
					should_receive( :handle_response ).
					once.
					with( @response, @request )

				lambda {
					@daemon.filter_response( @response, @request )
				}.should_not raise_error()
			end


			### Resource storing

			it "knows how to store a new resource" do
				UUIDTools::UUID.stub!( :timestamp_create ).and_return( TEST_UUID_OBJ )
				body = mock( "body IO" )
				metadata = mock( "metadata hash" ).as_null_object

				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_return( :a_checksum )

				metadata_proxy = mock( "metadata proxy" ).as_null_object
				metastore.should_receive( :transaction ).and_yield
				metastore.should_receive( :[] ).with( TEST_UUID_OBJ ).and_return( metadata_proxy )
				metadata_proxy.should_receive( :update ).with( metadata )

				metadata_proxy.should_receive( :checksum= ).with( :a_checksum )
				metadata_proxy.should_receive( :created ).and_return( nil )
				metadata_proxy.should_receive( :created= ).with an_instance_of( Time )
				metadata_proxy.should_receive( :modified= ).with( an_instance_of(Time) )

				metadata_proxy.stub!( :extent ).and_return( 1 )

				@daemon.store_resource( body, metadata ).should == TEST_UUID_OBJ
			end


			it "knows how to store related resources" do
				related_body = mock( "related body IO" )
				request = mock( "request object" )
				extracted_metadata = { 'stuff' => 'do good vote charlie' }
				related_metadata = { 'format' => 'image/png' }

				request.should_receive( :related_resources ).
					at_least( :once ).
					and_return({ :body => { related_body => related_metadata } })
				request.should_receive( :metadata ).
					and_return({ related_body => extracted_metadata })

				metadata = extracted_metadata.merge( related_metadata )
				metadata[ :related_to ] = TEST_UUID

				@daemon.should_receive( :store_resource ).with( related_body, metadata )

				@daemon.store_related_resources( :body, TEST_UUID, request )
			end


			it "knows how to purge specific related resources" do
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				results = [
					[ TEST_UUID2, {:title => 'Chunker'} ],
					[ TEST_UUID3, {:title => 'Chunker'} ],
				]

				search_criteria = {
					:related_to => TEST_UUID,
					:relation   => 'thumbnail'
				}
				metastore.should_receive( :find_by_exact_properties ).
					with( search_criteria ).
					and_return( results )

				metastore.should_receive( :delete_resource ).with( TEST_UUID2 )
				metastore.should_receive( :delete_resource ).with( TEST_UUID3 )
				filestore.should_receive( :delete ).with( TEST_UUID2 )
				filestore.should_receive( :delete ).with( TEST_UUID3 )

				@daemon.purge_related_resources( TEST_UUID, 'thumbnail' )
			end

			it "knows how to purge all related resources" do
				filestore = mock( "filestore" )
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" )
				@daemon.instance_variable_set( :@metastore, metastore )

				results = [
					[ TEST_UUID2, {:title => 'Chunker'} ],
					[ TEST_UUID3, {:title => 'Chunker'} ],
				]
				search_criteria = {
					:related_to => TEST_UUID,
					:relation => nil
				}
				metastore.should_receive( :find_by_exact_properties ).
					with( search_criteria ).
					and_return( results )

				metastore.should_receive( :delete_resource ).with( TEST_UUID2 )
				metastore.should_receive( :delete_resource ).with( TEST_UUID3 )
				filestore.should_receive( :delete ).with( TEST_UUID2 )
				filestore.should_receive( :delete ).with( TEST_UUID3 )

				@daemon.purge_related_resources( TEST_UUID )
			end

			it "knows how to recursively purge related resources"

			it "doesn't propagate errors that occur while storing a related resource" do
				related_body = mock( "related body IO" )
				request = mock( "request object" )
				extracted_metadata = { 'stuff' => 'do good vote charlie' }
				related_metadata = { 'format' => 'image/png' }

				request.should_receive( :related_resources ).
					at_least( :once ).
					and_return({ :body => { related_body => related_metadata } })
				request.should_receive( :metadata ).
					and_return({ related_body => extracted_metadata })

				metadata = extracted_metadata.merge( related_metadata )
				metadata[ :related_to ] = TEST_UUID

				@daemon.should_receive( :store_resource ).
					and_raise( ThingFish::FileStoreQuotaError.new("centipede-infested") )

				lambda {
					@daemon.store_related_resources( :body, TEST_UUID, request )
				}.should_not raise_error()
			end


			it "removes spoolfiles on successful uploads" do
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )

				spool = mock( "spoolfile" ).as_null_object
				metadata = { :extent => '2100' }

				spool.should_receive( :respond_to? ).
					with( :unlink ).
					and_return( true )

				spool.should_receive( :unlink )

				@daemon.store_resource( spool, metadata )
			end


			it "knows how to update the data and metadata for an existing resource" do
				body = mock( "body IO" )
				metadata = mock( "metadata hash" ).as_null_object

				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_return( :a_checksum )

				metastore.should_receive( :transaction ).and_yield
				metadata_proxy = mock( "metadata proxy" ).as_null_object
				metastore.should_receive( :[] ).with( TEST_UUID_OBJ ).and_return( metadata_proxy )
				metadata_proxy.should_receive( :update ).with( metadata )

				metadata_proxy.should_receive( :checksum= ).with( :a_checksum )
				metadata_proxy.should_receive( :created ).and_return( Time.now )
				metadata_proxy.should_not_receive( :created= )
				metadata_proxy.should_receive( :modified= ).with( an_instance_of(Time) )

				metadata_proxy.stub!( :extent ).and_return( 1 )

				@daemon.store_resource( body, metadata, TEST_UUID_OBJ ).should == TEST_UUID_OBJ
			end


			it "cleans up new resources if there's an error while storing the resource" do
				UUIDTools::UUID.stub!( :timestamp_create ).and_return( TEST_UUID_OBJ )
				body = mock( "body IO" )
				metadata = mock( "metadata hash" ).as_null_object

				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_raise( RuntimeError.new('Happy time explosion!') )
				filestore.should_receive( :delete ).with( TEST_UUID_OBJ )

				lambda {
					@daemon.store_resource( body, metadata )
				}.should raise_error( RuntimeError, 'Happy time explosion!' )
			end


			it "cleans up new resources if there's an error while storing the metadata" do
				UUIDTools::UUID.should_receive( :timestamp_create ).and_return( TEST_UUID_OBJ )
				body = mock( "body IO" )
				metadata = mock( "metadata hash" ).as_null_object

				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" )
				@daemon.instance_variable_set( :@metastore, metastore )
				md_proxy = mock( "metadata proxy" )

				metastore.should_receive( :transaction ).and_yield
				metastore.should_receive( :[] ).with( TEST_UUID_OBJ ).and_return( md_proxy )
				md_proxy.should_receive( :update ).
				 	and_raise( RuntimeError.new('JeffCon 2008: I was there') )
				filestore.should_receive( :delete ).with( TEST_UUID_OBJ )

				lambda {
					@daemon.store_resource( body, metadata  )
				}.should raise_error( RuntimeError, 'JeffCon 2008: I was there' )
			end


			it "does not delete the resource if there's an error while updating" do
				body = mock( "body IO" )
				metadata = mock( "metadata hash" ).as_null_object

				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore" ).as_null_object
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore" ).as_null_object
				@daemon.instance_variable_set( :@metastore, metastore )

				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_raise( RuntimeError.new('Happy time explosion!') )
				filestore.should_not_receive( :delete ).with( TEST_UUID_OBJ )

				lambda {
					@daemon.store_resource( body, metadata, TEST_UUID_OBJ )
				}.should raise_error( RuntimeError, 'Happy time explosion!' )
			end
		end

	end


	it "creates its listener with specific socket flags turned on" do
		socket = mock( "TCPServer socket" )
		TCPServer.should_receive( :new ).and_return( socket )
		socket.should_receive( :setsockopt ).with( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1 )

		ThingFish::Daemon.new
	end

	it "uses default config IP when constructed with no arguments" do
		socket = stub( "TCPServer socket", :setsockopt => nil )
		ip, port = ThingFish::Config::DEFAULTS.values_at( :ip, :port )
		TCPServer.should_receive( :new ).with( ip, port ).and_return( socket )

		ThingFish::Daemon.new
	end

	it "uses default config IP when constructed with a differing ip config" do
		socket = stub( "TCPServer socket", :setsockopt => nil )
		config = ThingFish::Config.new
		ThingFish.logger.debug "Setting value for ip to: %p" % [ TEST_IP ]
		config.ip = TEST_IP

		port = ThingFish::Config::DEFAULTS[:port]
		TCPServer.should_receive( :new ).with( TEST_IP, port ).and_return( socket )

		ThingFish::Daemon.new( config )
	end


	it "uses default config port when constructed with a differing port config" do
		socket = stub( "TCPServer socket", :setsockopt => nil )
		config = ThingFish::Config.new
		config.port = TEST_PORT

		ip = ThingFish::Config::DEFAULTS[:ip]
		TCPServer.should_receive( :new ).with( ip, TEST_PORT ).and_return( socket )

		ThingFish::Daemon.new( config )
	end


	describe " started as root with a user configured" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.user = 'not-root'
			@daemon = ThingFish::Daemon.new( @config )

			@listener_thread = mock( "listener thread" )
		end


		it "drops privileges" do
			@daemon.should_receive( :start_supervisor_thread )
			@daemon.should_receive( :start_listener ).and_return( @listener_thread )
			@listener_thread.should_receive( :join )

			Process.should_receive( :euid ).at_least( :once ).and_return(0)

			pwent = mock( 'not-root pw entry' )
			Etc.should_receive( :getpwnam ).with( @config.user ).and_return( pwent )
			pwent.should_receive( :uid ).and_return( 1000 )

			Process.should_receive( :euid= ).with( 1000 )

			client = stub( "client socket" )
			@listener.stub!( :accept ).and_return { @daemon.shutdown; client }
			client.stub!( :peeraddr ).and_return( [1,2,3] )
			@listener.stub!( :close )

			conn_threadgroup = stub( "connection threadgroup", :add => nil, :list => [] )
			@daemon.instance_variable_set( :@connection_threads, conn_threadgroup )

			@daemon.start
		end

	end


	describe " with one or more handlers in its configuration" do

		before( :all ) do
			setup_logging( :fatal )
		end

		after( :all ) do
			reset_logging()
		end

		before(:each) do
			@config = ThingFish::Config.new
			@config.logging.level = Logger::DEBUG
			@config.logging.logfile = 'stderr'
			@config.plugins.urimap = { '/test' => 'test' }

			@daemon = ThingFish::Daemon.new( @config )
		end


		it "registers its configured handlers" do
			@daemon.urimap.map.length.should == 2
		end

		it "can describe its handlers for the server info hash" do
			# @daemon.handler_info.should have(3).members

			@daemon.handler_info.should have_key( 'default' )
			@daemon.handler_info.should have_key( 'staticcontent' )

			@daemon.handler_info.should have_key( 'test' )
			@daemon.handler_info['test'].should have(1).members
			@daemon.handler_info['test'].should include('/test')
		end
	end


	describe " with profiling configured" do

		after( :all ) do
			reset_logging()
		end

		before(:each) do
			@config = ThingFish::Config.new
			setup_logging( :fatal )
			@config.profiling.enabled = true
		end


		it "attempts to load and configure the ruby-prof library" do
			@config.profiling.metrics = %w[]
			RubyProf.should_receive( :measure_mode= ).with( 1 )

			daemon = ThingFish::Daemon.allocate
			daemon.should_receive( :require ).with( 'ruby-prof' ).and_return( true )
			daemon.__send__( :initialize, @config )
			daemon.have_profiling.should == true
		end


		it "adds additional metrics to the profiling config if they're available and enabled" do
			@config.profiling.metrics = %w[ cpu allocations memory ]
			RubyProf.should_receive( :measure_mode= ).with( 15 )

			daemon = ThingFish::Daemon.allocate
			daemon.should_receive( :require ).with( 'ruby-prof' ).and_return( true )
			daemon.__send__( :initialize, @config )
			daemon.have_profiling.should == true
		end


		it "doesn't propagate exceptions thrown while loading" do
			daemon = ThingFish::Daemon.allocate
			daemon.should_receive( :require ).
				with( 'ruby-prof' ).
				and_raise( LoadError.new("Something bad!!") )

			lambda {
				daemon.__send__( :initialize, @config )
			}.should_not raise_error()

			daemon.have_profiling.should == false
		end


		it "profiles the life of the request" do
			request  = mock( "thingfish request" )
			request.stub!( :http_version ).and_return( 1.1 )
			response = mock( "thingfish response" )

			RubyProf.should_receive( :measure_mode= ).with( 1 )
			daemon = ThingFish::Daemon.allocate
			daemon.should_receive( :require ).with( 'ruby-prof' ).and_return( true )
			daemon.__send__( :initialize, @config )

			ThingFish::Response.should_receive( :new ).with( 1.1, @config ).and_return( response )

			uri = URI.parse( "http://localhost:3474/search?_profile=1" )
			request.should_receive( :run_profile? ).and_return( true )
			request.should_receive( :uri ).at_least( :once ).and_return( uri )

			result = mock( "Ruby-prof result object" )
			RubyProf.should_receive( :profile ).and_return( result )

			fh = mock( "filehandle" )
			File.should_receive( :open ).with( /\d+\.\d+#-?[[:xdigit:]]+#search\.html$/, 'w' ).and_yield( fh )

			### We're currently working on the marshalling aspect of ruby-prof.
			###
			# Marshal.should_receive( :dump ).with([ tf_request, result ]).and_return( :dumped_stuff )
			# fh.should_receive( :print ).with( :dumped_stuff )

			# Mocking the class under test to avoid mocking a whole bunch of other
			# stuff we don't care about (that is already tested.)
			daemon.dispatch( request )
		end
	end

end


# vim: set nosta noet ts=4 sw=4:
