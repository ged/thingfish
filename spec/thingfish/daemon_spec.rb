#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/daemon'
	require 'thingfish/config'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestConstants

class TestHandler < ThingFish::Handler
end


# Expose some methods for testing (ick, but we can't test through Mongrel any 
# other way)
class ThingFish::Daemon
	public :dispatch,
		:dispatch_to_handlers,
		:run_handlers,
		:send_response,
		:filter_request,
		:filter_response
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Daemon do
	include ThingFish::SpecHelpers
	
	before(:all) do
		setup_logging( :fatal )
	end
	

	before( :each ) do
		# Have to set up logging each time, 'cause Daemon alters it in some examples
		setup_logging( :fatal )

		# Stop the daemon from actually doing anything in another thread or
		# listening on a real socket.
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )

		@acceptor_thread = mock( "Mock Thread" )
		Thread.stub!( :new ).and_return( @acceptor_thread )
	end
	
	after( :each ) do
		ThingFish.reset_logger
	end


	after( :all ) do
		ThingFish.reset_logger
	end

	

	### Logging

	it "outputs a new instance's handler config to the debug log" do
		log = StringIO.new('')
		ThingFish.logger = Logger.new( log )

		daemon = ThingFish::Daemon.new

		log.rewind
		log.read.should =~ %r{Handler map is:\s*/: \[.*?\]}
	end


	### End-to-end 
	describe " configured with defaults" do

		before( :each ) do
			@config = ThingFish::Config.new
			@config.defaulthandler.resource_dir = 'var/www'
			@daemon = ThingFish::Daemon.new( @config )
			
			@handlers = []
			@filters = []

			@client = mock( "client socket object" )
			@client.stub!( :closed? ).and_return( false )

			@request = mock( "request object", :null_object => true )
			@response = mock( "response object", :null_object => true )

			@request_headers = mock( "mock request headers", :null_object => true )
			@response_headers = mock( "mock response headers", :null_object => true )

			@request.stub!( :headers ).and_return( @request_headers )
			@request.stub!( :http_method ).and_return( 'GET' )

			@response.stub!( :status ).
				and_return( ThingFish::Response::DEFAULT_STATUS )
			@response.stub!( :headers ).and_return( @response_headers )
			@response.stub!( :handlers ).and_return( @handlers )
			@response.stub!( :filters ).and_return( @filters )
			@response.stub!( :is_handled? ).and_return( false )
			@response.stub!( :body ).and_return( "" )
		end
		
		
		it "wraps the mongrel request and response objects in their ThingFish counterparts" do
			m_request   = stub( "mongrel request object" )
			m_response  = stub( "mongrel response object" )
			tf_request  = stub( "thingfish request" )
			tf_response = stub( "thingfish response" )

			ThingFish::Request.should_receive( :new ).with( m_request, @config ).
				and_return( tf_request )
			ThingFish::Response.should_receive( :new ).with( m_response ).
				and_return( tf_response )

			# We're mocking a method on the class under test here, which is usually
			# a really bad idea, but the alternative is to mock out a whole
			# bunch of other stuff that happens in #dispatch_to_handlers that is
			# beside the point (and already tested).
			@daemon.should_receive( :dispatch_to_handlers ).
				with( @client, @handlers, tf_request, tf_response )
			@daemon.dispatch( @client, @handlers, m_request, m_response )
		end
		

		### Response generation
		describe " response handling" do

			it "returns a valid http 404 response if no filter or handler sets the response status" do
				@request.should_receive( :accepts? ).with( XHTML_MIMETYPE ).
					and_return( false )

				@response.should_receive( :content_type= ).and_return( 'text/plain' )
				@response.should_receive( :reset )
				@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
				@response.should_receive( :body= ).with( /404 \(Not Found\)/i )

				@response.should_receive( :write ).at_least( 3 ).times
				@response.should_receive( :done= ).with( true )

				@daemon.dispatch_to_handlers( @client, @handlers, @request, @response )
			end


			it "returns a not acceptable response if the body is set and the content-type " +
				"doesn't match a mimetype specified by the request's Accept header" do

				@response.should_receive( :is_handled? ).at_least( :once ).and_return( true )
				@response.should_receive( :body ).at_least( :once ).and_return( "something_other_than_nil" )
				@response.should_receive( :status_is_successful? ).and_return( true )
				@response.should_receive( :content_type ).at_least( :once ).and_return( RUBY_MIMETYPE )
				@request.should_receive( :accepts? ).with( RUBY_MIMETYPE ).and_return( false )

				# send_error_response
				@response.should_receive( :reset )
				@response.should_receive( :status= ).with( HTTP::NOT_ACCEPTABLE )
				@request.should_receive( :accepts? ).with( XHTML_MIMETYPE ).and_return( false )

				@response.should_receive( :content_type= ).with( 'text/plain' )

				@daemon.dispatch_to_handlers( @client, [], @request, @response )
			end


			it "doesn't do 'not acceptable' checking if the body is nil" do
				@response.should_receive( :is_handled? ).at_least( :once ).and_return( true )
				@response.should_receive( :body ).at_least( :once ).and_return( nil )

				@response.stub!( :status ).and_return( HTTP::OK )
				@response.should_not_receive( :status= ).with( HTTP::NOT_ACCEPTABLE )

				@daemon.dispatch_to_handlers( @client, [], @request, @response )
			end


			it "does not try to send the response if the client closes the connection early" do
				@response.should_receive( :filters ).and_return( @filters )
				@response.should_receive( :is_handled? ).at_least( :once ).and_return( true )
				@response.should_receive( :body ).at_least( :once ).and_return( nil )

				@client.should_receive( :closed? ).at_least(:once).and_return( true )
				@response.should_not_receive( :write )

				@daemon.dispatch_to_handlers( @client, @handlers, @request, @response )
			end


			it "sends a valid http response to the client after a successful run" do
				filter = mock( "filter", :null_object => true )

				@daemon.filters << filter

				filter.
					should_receive( :handle_request ).
					with( @request, @response )
				@response.stub!( :is_handled? ).and_return( true ) # Skips handlers
				filter.
					should_receive( :handle_response ).
					with( @response, @request )

				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::OK )
				@response.should_receive( :write ).with( /200 ok/i )
				@response_headers.should_receive( :to_s ).and_return( 'the headers' )
				@response.should_receive( :write ).with( /the headers/ )
				@response.should_receive( :body ).at_least( :once ).and_return( 'the_body' )
				@response.should_receive( :write ).with( 'the_body' )

				@daemon.dispatch_to_handlers( @client, @handlers, @request, @response )
			end


			it "sends a valid http response without an entity body if the request is a HEAD" do
				filter = mock( "filter", :null_object => true )

				@daemon.filters << filter

				filter.
					should_receive( :handle_request ).
					with( @request, @response )
				@response.stub!( :is_handled? ).and_return( true ) # Skips handlers
				filter.
					should_receive( :handle_response ).
					with( @response, @request )

				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::OK )
				@response.should_receive( :write ).with( /200 ok/i )
				@response_headers.should_receive( :to_s ).and_return( 'the headers' )
				@response.should_receive( :write ).with( /the headers/ )
				@request.should_receive( :http_method ).and_return( 'HEAD' )
				@response.stub!( :body ).and_return( 'the response body' )
				@response.should_not_receive( :write ).with( 'the response body' )

				@daemon.dispatch_to_handlers( @client, @handlers, @request, @response )
			end

		end


		### Handlers
		describe " handler dispatching" do

			it "runs through all of its handlers if none of them set the response status" do
				handler_list = []

				second_handler = mock( "second handler", :null_object => true )
				@handler.should_receive( :process )
				@response.should_receive( :handlers ).
					twice.
					and_return( handler_list )
				@response.should_receive( :is_handled? ).
					twice.
					and_return( false )

				second_handler.should_receive( :process )

				handlers = [ @handler, second_handler ]
				@daemon.run_handlers( @client, handlers, @request, @response )

				handler_list.should have(2).members
				handler_list[0].should == @handler
				handler_list[1].should == second_handler
			end

			it "iterates through its handlers and stops if any of them set response status" do
				handler_list = []
				second_handler = mock( "second handler", :null_object => true )

				@handler.should_receive( :process )
				@response.should_receive( :handlers ).
					once.
					and_return( handler_list )
				@response.should_receive( :is_handled? ).
					once.
					and_return( true )

				second_handler.should_not_receive( :process )

				handlers = [ @handler, second_handler ]
				@daemon.run_handlers( @client, handlers, @request, @response )

				handler_list.should have(1).member
				handler_list[0].should == @handler
			end


			it "iterates through its handlers and stops if the connection is closed" do
				handler_list = []
				second_handler = mock( "second handler", :null_object => true )

				client = mock( "client object", :null_object => true )
				client.should_receive( :closed? ).and_return( true )

				@handler.should_receive( :process )
				@response.should_receive( :handlers ).
					once.
					and_return( handler_list )
				@response.should_receive( :is_handled? ).
					once.
					and_return( false )

				second_handler.should_not_receive( :process )

				handlers = [ @handler, second_handler ]
				@daemon.run_handlers( client, handlers, @request, @response )

				handler_list.should have(1).member
				handler_list[0].should == @handler
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
				info.should have(2).members
				info.keys.should include( 'eins', 'zwei' )
				info.values.should include( :eins_info, :zwei_info )
			end
			

			it "iterates through its filters on incoming requests" do
				filter_uno = mock( "request filter number one", :null_object => true )
				filter_dos = mock( "request filter number two", :null_object => true )

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
				filter_uno = mock( "request filter number one", :null_object => true )
				filter_dos = mock( "request filter number two", :null_object => true )

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
				filter_uno  = mock( "request filter number one", :null_object => true )
				filter_dos  = mock( "request filter number two", :null_object => true )
				filter_tres = mock( "request filter number three", :null_object => true )
				
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
				filter_uno = mock( "response filter number one", :null_object => true )
				filter_dos = mock( "response filter number two", :null_object => true )
				
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
			
		
		
			### Content-length
		
			it "asks the response for its content length if the content-length header hasn't " +
				"been set" do
				headers = mock( "response headers", :null_object => true )
				headers.should_receive( :[] ).
					at_least( :once ).
					with( :content_length ).
					and_return( nil )
				
				@response.should_receive( :headers ).at_least( :once ).and_return( headers )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::OK )
				@response.should_receive( :get_content_length ).and_return( 15 )
				@daemon.send_response( @response, @request )
			end
			
		
			### Buffering/unbuffered response
		
			it "buffers the response when the body implements #read" do
				headers = mock( "response headers", :null_object => true )
				headers.should_receive( :[] ).
					at_least( :once ).
					with( :content_length ).
					and_return( nil )
				
				@response.should_receive( :headers ).at_least( :once ).and_return( headers )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::OK )
				
				response_body = mock( "response body", :null_object => true )
				@response.should_receive( :body ).
					at_least( :once ).
					and_return( response_body )
		
				testdata = 'this is some data for testing'
				testbuf = testdata.dup
		
				response_body.should_receive( :respond_to? ).
					with( :read ).
					and_return( true )
				response_body.should_receive( :read ).twice.
					with( an_instance_of(Fixnum), '' ).
					and_return do |size,buf|
						buf << testbuf.slice!( 0, testbuf.length )
						buf.empty? ? nil : buf.length
					end
		
				@response.should_receive( :write ).
					with( testdata ).
					and_return( testdata.length )
				
				@daemon.send_response( @response, @request )
			end
			
			
			it "doesn't buffer the response when the body is in memory" do
				headers = mock( "response headers", :null_object => true )
				headers.should_receive( :[] ).
					at_least( :once ).
					with( :content_length ).
					and_return( nil )
				
				@response.should_receive( :headers ).at_least( :once ).and_return( headers )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::OK )
				
				response_body = mock( "response body", :null_object => true )
				@response.should_receive( :body ).
					at_least( :once ).
					and_return( response_body )
		
				testdata = 'this is some data for testing'
		
				response_body.should_receive( :respond_to? ).
					with( :read ).
					and_return( false )
				response_body.should_receive( :to_s ).once.
					and_return( testdata )
					
				@response.should_receive( :write ).
					with( testdata ).
					and_return( testdata.length )
				
				@daemon.send_response( @response, @request )
			end
			
			
			### Exception-handling
			it "handles uncaught exceptions with an HTML error page if the content-" +
				"negotiation headers indicate HTML is acceptable" do
				erroring_handler = mock( "erroring handler", :null_object => true )

				erroring_handler.should_receive( :process ).
					and_raise( RuntimeError.new("some error") )

				@response.should_receive( :is_handled? ).and_return( false )
				@request.should_receive( :accepts? ).with( XHTML_MIMETYPE ).and_return( true )
				@response.should_receive( :content_type= ).with( XHTML_MIMETYPE )
				@response.stub!( :data ).and_return( {} )
				@request.stub!( :path_info ).and_return( '/poon' )
				@response.should_receive( :body= ).with( /<html.*some error/mi )

				# Status line
				@response.should_receive( :status= ).with( HTTP::SERVER_ERROR )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::SERVER_ERROR )
				@response.should_receive( :write ).with( /500 internal server error/i )

				# Headers
				@response_headers.should_receive( :[]= ).with( :connection, 'close' )
				@response_headers.should_receive( :[] ).with( :content_length ).and_return( nil )
				@response.should_receive( :get_content_length ).and_return( :the_length )
				@response_headers.should_receive( :[]= ).with( :content_length, :the_length )
				@response_headers.should_receive( :[]= ).with( :date, /\d+:\d+:\d+/ )
				@response_headers.should_receive( :to_s ).and_return( "the_headers" )
				@response.should_receive( :write ).with( /the_headers\r\n/ )
				
				# Body
				@response.should_receive( :body ).and_return( :the_response_body )
				@response.should_receive( :write ).with( 'the_response_body' )

				@response.should_receive( :done= ).with( true )
		
				@daemon.dispatch_to_handlers( @client, [erroring_handler], @request, @response )
			end
			
			
			it "handles uncaught exceptions with a plain-text response if HTML isn't acceptable" do
				erroring_handler = mock( "erroring handler", :null_object => true )

				erroring_handler.should_receive( :process ).
					and_raise( RuntimeError.new("some error") )

				@response.should_receive( :is_handled? ).and_return( false )
				@request.should_receive( :accepts? ).with( XHTML_MIMETYPE ).and_return( false )
				@response.should_receive( :content_type= ).with( 'text/plain' )
				@response.should_receive( :body= ).with( /500.*error/i )

				# Status line
				@response.should_receive( :status= ).with( HTTP::SERVER_ERROR )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::SERVER_ERROR )
				@response.should_receive( :write ).with( /500 internal server error/i )

				# Headers
				@response_headers.should_receive( :[]= ).with( :connection, 'close' )
				@response_headers.should_receive( :[] ).with( :content_length ).and_return( nil )
				@response.should_receive( :get_content_length ).and_return( :the_length )
				@response_headers.should_receive( :[]= ).with( :content_length, :the_length )
				@response_headers.should_receive( :[]= ).with( :date, /\d+:\d+:\d+/ )
				@response_headers.should_receive( :to_s ).and_return( "the_headers" )
				@response.should_receive( :write ).with( /the_headers\r\n/ )
				
				# Body
				body = ''
				@response.should_receive( :body ).twice.and_return( body )
				@response.should_receive( :write ).with( body )

				@response.should_receive( :done= ).with( true )
		
				@daemon.dispatch_to_handlers( @client, [erroring_handler], @request, @response )
			end
			
		
			it "handles uncaught request errors with a valid http BAD_REQUEST response" do
				erroring_handler = mock( "mock handler", :null_object => true )
				
				erroring_handler.should_receive( :process ).
					and_raise( ThingFish::RequestError.new("bad client! no cupcake!") )
		
				@response.should_receive( :is_handled? ).and_return( false )
				@request.should_receive( :accepts? ).with( XHTML_MIMETYPE ).and_return( true )
				@response.should_receive( :content_type= ).with( XHTML_MIMETYPE )

				# Status line
				@response.should_receive( :status= ).with( HTTP::BAD_REQUEST )
				@response.should_receive( :status ).at_least( :once ).and_return( HTTP::BAD_REQUEST )
				@response.should_receive( :write ).with( /400 bad request/i )

				# Headers
				@response_headers.should_receive( :[]= ).with( :connection, 'close' )
				@response_headers.should_receive( :[] ).with( :content_length ).and_return( nil )
				@response.should_receive( :get_content_length ).and_return( :the_length )
				@response_headers.should_receive( :[]= ).with( :content_length, :the_length )
				@response_headers.should_receive( :[]= ).with( :date, /\d+:\d+:\d+/ )
				@response_headers.should_receive( :to_s ).and_return( "the_headers" )
				@response.should_receive( :write ).with( /the_headers\r\n/ )
				
				# Body
				@response.should_receive( :body ).and_return( :the_response_body )
				@response.should_receive( :write ).with( 'the_response_body' )

				@response.should_receive( :done= ).with( true )
		
				@daemon.dispatch_to_handlers( @client, [erroring_handler], @request, @response )
			end
			
			
			### Resource storing
			
			it "knows how to store a new resource" do
				UUID.stub!( :timestamp_create ).and_return( TEST_UUID_OBJ )
				body = mock( "body IO" )
				metadata = mock( "metadata hash", :null_object => true )
		
				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore", :null_object => true )
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore", :null_object => true )
				@daemon.instance_variable_set( :@metastore, metastore )
		
				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_return( :a_checksum )
		
				metadata_proxy = mock( "metadata proxy", :null_object => true )
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
			
			
			it "removes spoolfiles on successful uploads" do
				filestore = mock( "filestore", :null_object => true )
				@daemon.instance_variable_set( :@filestore, filestore )
				
				spool = mock( "spoolfile", :null_object => true )
				metadata = {}
				
				spool.should_receive( :respond_to? ).
					with( :unlink ).
					and_return( true )
				
				spool.should_receive( :unlink )
				
				@daemon.store_resource( spool, metadata )
			end
			
			
			it "knows how to update the data and metadata for an existing resource" do
				body = mock( "body IO" )
				metadata = mock( "metadata hash", :null_object => true )
		
				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore", :null_object => true )
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore", :null_object => true )
				@daemon.instance_variable_set( :@metastore, metastore )
		
				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_return( :a_checksum )
		
				metastore.should_receive( :transaction ).and_yield
				metadata_proxy = mock( "metadata proxy", :null_object => true )
				metastore.should_receive( :[] ).with( TEST_UUID_OBJ ).and_return( metadata_proxy )
				metadata_proxy.should_receive( :update ).with( metadata )
		
				metadata_proxy.should_receive( :checksum= ).with( :a_checksum )
				metadata_proxy.should_receive( :created ).and_return( Time.now )
				metadata_proxy.should_not_receive( :created= )
				metadata_proxy.should_receive( :modified= ).with( an_instance_of(Time) )
		
				metadata_proxy.stub!( :extent ).and_return( 1 )
		
				@daemon.store_resource( body, metadata, TEST_UUID_OBJ ).should == TEST_UUID_OBJ
			end
		
		
			it "cleans up new resources if there's an error while storing" do
				UUID.stub!( :timestamp_create ).and_return( TEST_UUID_OBJ )
				body = mock( "body IO" )
				metadata = mock( "metadata hash", :null_object => true )
		
				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore", :null_object => true )
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore", :null_object => true )
				@daemon.instance_variable_set( :@metastore, metastore )
		
				filestore.should_receive( :store_io ).
					with( TEST_UUID_OBJ, body ).
					and_raise( RuntimeError.new('Happy time explosion!') )
				filestore.should_receive( :delete ).with( TEST_UUID_OBJ )
				
				lambda {
					@daemon.store_resource( body, metadata )
				}.should raise_error( RuntimeError, 'Happy time explosion!' )
			end
			
			
			it "does not delete the resource if there's an error while updating" do
				body = mock( "body IO" )
				metadata = mock( "metadata hash", :null_object => true )
		
				# Replace the filestore and metastore with mocks
				filestore = mock( "filestore", :null_object => true )
				@daemon.instance_variable_set( :@filestore, filestore )
				metastore = mock( "metastore", :null_object => true )
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


	describe " constructed with no arguments" do

		before(:each) do
			@daemon = ThingFish::Daemon.new
		end

		it "uses default config IP" do
			@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
		end

		it "uses default config port" do
			@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port])
		end
	end


	describe " with a differing ip config" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.ip = TEST_IP

			@daemon = ThingFish::Daemon.new( @config )
		end

		it "binds to the test ip" do
			@daemon.host.should equal( TEST_IP ) if @daemon
		end

		it "uses default config port" do
			@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port] ) if @daemon
		end
	end


	describe " started as root with a user configured" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.user = 'not-root'
			@daemon = ThingFish::Daemon.new( @config )
		end


		it "drops privileges" do
			Process.should_receive( :euid ).at_least( :once ).and_return(0)
	
			pwent = mock( 'not-root pw entry' ) 
			Etc.should_receive( :getpwnam ).with( @config.user ).and_return( pwent )
			pwent.should_receive( :uid ).and_return( 1000 )

			Process.should_receive( :euid= ).with( 1000 )
			@daemon.run
		end
	end


	describe " with a differing port config" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.port = TEST_PORT
			@daemon = ThingFish::Daemon.new( @config )
		end

		it "uses default config IP" do
			@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
		end

		it "binds to the test port" do
			@daemon.port.should equal( TEST_PORT )
		end
	end


	describe " with an ip and host configured" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.ip = TEST_IP
			@config.port = TEST_PORT
			@daemon = ThingFish::Daemon.new( @config )
		end

		it "binds to the test ip" do
			@daemon.host.should equal( TEST_IP )
		end

		it "binds to test port" do
			@daemon.port.should equal( TEST_PORT )
		end

	end


	describe " with one or more handlers in its configuration" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.plugins.handlers = [
				{'test' => '/test' },
			]
		
			@daemon = ThingFish::Daemon.new( @config )
		end

		it "registers its configured handlers" do
			@daemon.classifier.uris.length.should == 2
		end

		it "can describe its handlers for the server info hash" do
			@daemon.handler_info.should have(3).members

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
			m_request   = stub( "mongrel request object" )
			m_response  = stub( "mongrel response object" )
			tf_request  = stub( "thingfish request" )
			tf_response = stub( "thingfish response" )
			
			RubyProf.should_receive( :measure_mode= ).with( 1 )
			daemon = ThingFish::Daemon.allocate
			daemon.should_receive( :require ).with( 'ruby-prof' ).and_return( true )
			daemon.__send__( :initialize, @config )

			client = mock( "client socket object" )

			ThingFish::Request.should_receive( :new ).with( m_request, @config ).
				and_return( tf_request )
			ThingFish::Response.should_receive( :new ).with( m_response ).
				and_return( tf_response )

			uri = URI.parse( "http://localhost:3474/search?_profile=1" )
			tf_request.should_receive( :run_profile? ).and_return( true )
			tf_request.should_receive( :uri ).and_return( uri )

			result = mock( "Ruby-prof result object" )
			RubyProf.should_receive( :profile ).and_yield.and_return( result )
			
			fh = mock( "filehandle" )
			File.should_receive( :open ).with( /\d+\.\d+#-?\d+#search\.html$/, 'w' ).and_yield( fh )
			
			### We're currently working on the marshalling aspect of ruby-prof.
			###
			# Marshal.should_receive( :dump ).with([ tf_request, result ]).and_return( :dumped_stuff )
			# fh.should_receive( :print ).with( :dumped_stuff )

			# Mocking the class under test to avoid mocking a whole bunch of other
			# stuff we don't care about (that is already tested.) 
			daemon.should_receive( :dispatch_to_handlers ).
				with( client, [], tf_request, tf_response )
			daemon.dispatch( client, [], m_request, m_response )
		end
	end


	### This is really testing outside our purview -- it's up to our superclass
	### to correctly shut down -- but it's here for coverage of the path around
	### the call to Mongrel::HttpServer#stop.
	describe " (while running)" do

		before(:each) do
			@config = ThingFish::Config.new
			@config.port = 7777
			@config.logging.level = 'fatal'
			@daemon = ThingFish::Daemon.new( @config )
		end


		it "stops executing when shut down" do
			@daemon.run
			
			@acceptor_thread.should_receive( :raise ).with( an_instance_of(Mongrel::StopServer) )
			
			@daemon.shutdown
		end
	end
end


# vim: set nosta noet ts=4 sw=4:
