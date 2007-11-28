#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

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
	public :dispatch_to_handlers,
		:run_handlers,
		:send_response,
		:filter_request,
		:filter_response
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Daemon do
	
	before( :each ) do
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )

		@config = ThingFish::Config.new
		@config.defaulthandler.resource_dir = 'var/www'

		@daemon = ThingFish::Daemon.new( @config )
		@request = mock( "mongrel request", :null_object => true )
		@response = mock( "mongrel response", :null_object => true )
		@handler = mock( "handler", :null_object => true )
		@client = stub( "client", :closed? => false )
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
	it "returns a valid http 404 response if no filter or handler sets the response status" do
		@response.should_receive( :write ).with( /404 not found/i )
		@response.should_receive( :write ).with( /content-type:/i )
		@response.should_receive( :write ).with( /<html/i )
		
		@daemon.dispatch_to_handlers( @client, [], @request, @response )
	end
	
	
	it "returns a not acceptable response if the body is set and the content-type " +
	   "doesn't match a mimetype specified by the request's Accept header" do
		headers = mock( "Response headers", :null_object => true )

		tf_request  = mock( "ThingFish request",  :null_object => true )
		tf_response = mock( "ThingFish response", :null_object => true )
		tf_response.stub!( :headers ).and_return( headers )
		
		ThingFish::Request.stub!( :new ).and_return( tf_request )
		ThingFish::Response.stub!( :new ).and_return( tf_response )
		
		tf_response.should_receive( :is_handled? ).
			at_least( :once ).
			and_return( true )
		tf_response.should_receive( :body ).
			at_least( :once ).
			and_return( "something_other_than_nil" )
		tf_response.should_receive( :headers ).
			at_least( :once ).
			and_return( headers )
		headers.should_receive( :[] ).
			at_least( :once ).
			with( :content_type ).
			and_return( RUBY_MIMETYPE )
		
		tf_request.should_receive( :accepts? ).
			with( RUBY_MIMETYPE ).
			and_return( false )

		tf_response.stub!( :status ).and_return( HTTP::OK )
		tf_response.should_receive( :status= ).with( HTTP::NOT_ACCEPTABLE )

		@daemon.dispatch_to_handlers( @client, [], @request, @response )
	end
	

	it "doesn't do 'not acceptable' checking if the body is nil" do
		headers = mock( "Response headers", :null_object => true )

		tf_request  = mock( "ThingFish request",  :null_object => true )
		tf_response = mock( "ThingFish response", :null_object => true )
		tf_response.stub!( :headers ).and_return( headers )
		
		ThingFish::Request.stub!( :new ).and_return( tf_request )
		ThingFish::Response.stub!( :new ).and_return( tf_response )
		
		tf_response.should_receive( :is_handled? ).
			at_least( :once ).
			and_return( true )
		tf_response.should_receive( :body ).
			at_least( :once ).
			and_return( nil )

		tf_response.stub!( :headers ).
			and_return( headers )
		headers.stub!( :[] ).
			and_return( RUBY_MIMETYPE )
		tf_request.stub!( :accepts? ).
			and_return( false )

		tf_response.stub!( :status ).and_return( HTTP::OK )
		tf_response.should_not_receive( :status= ).with( HTTP::NOT_ACCEPTABLE )

		@daemon.dispatch_to_handlers( @client, [], @request, @response )
	end
	

	it "does not try to send the response if the client closes the connection early" do
		filter = mock( "filter", :null_object => true )
		
		handlers = [ @handler ]
		@daemon.filters << filter

		filter.
			should_receive( :handle_request ).
			with( an_instance_of(ThingFish::Request), an_instance_of(ThingFish::Response) )
		@handler.
			should_receive( :process ).
			with( an_instance_of(ThingFish::Request), an_instance_of(ThingFish::Response) )
		filter.
			should_receive( :handle_response ).
			with( an_instance_of(ThingFish::Response), an_instance_of(ThingFish::Request) )

		@client.should_receive( :closed? ).at_least(:once).and_return( true )
		@response.should_not_receive( :write )
		
		@daemon.dispatch_to_handlers( @client, handlers, @request, @response )
	end
	

	it "sends a valid http response to the client after a successful run" do
		filter = mock( "filter", :null_object => true )
		
		handlers = [ @handler ]
		@daemon.filters << filter

		filter.
			should_receive( :handle_request ).
			with( an_instance_of(ThingFish::Request), an_instance_of(ThingFish::Response) )
		@handler.
			should_receive( :process ).
			with( an_instance_of(ThingFish::Request), an_instance_of(ThingFish::Response) ).
			and_return do |req, res|
				res.status = HTTP::OK
				res.headers[:content_type] = 'text/html'
				res.body = TEST_CONTENT
			end
		filter.
			should_receive( :handle_response ).
			with( an_instance_of(ThingFish::Response), an_instance_of(ThingFish::Request) )

		@client.should_receive( :closed? ).at_least(:once).and_return( false )
		@response.should_receive( :write ).with( /200 ok/i )
		@response.should_receive( :write ).with( %r{content-type: text/html}i )
		@response.should_receive( :write ).with( /<html/i )
		
		@daemon.dispatch_to_handlers( @client, handlers, @request, @response )
	end
	



	### Handlers

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


	### Filters
	
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
		@daemon.send_response( @response )
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
		
		@daemon.send_response( @response )
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
		
		@daemon.send_response( @response )
	end
	
	
	### Exception-handling
	it "handles uncaught exceptions with an HTML error page if the content-" +
		"negotiation headers indicate HTML is acceptable" do

		params    = {
			'HTTP_ACCEPT' => 'text/html'
		}
		request   = mock( "mongrel request" )
		response  = mock( "mongrel response" )

		erroring_handler = mock( "erroring handler", :null_object => true )
		
		erroring_handler.should_receive( :process ).
			and_raise( RuntimeError.new("some error") )
		request.should_receive( :params ).at_least( :once ).
			and_return( params )

		response.should_receive( :write ).at_least(:once).with( /500 internal server error/i )
		response.should_receive( :write ).at_least(:once).with( %r{content-type: text/html}i )
		response.should_receive( :write ).at_least(:once).with( /some error/i )
		response.should_receive( :done= ).with( anything() )

		client = mock( "client object", :null_object => true )
		# BRANCH: client returns true
		client.should_receive( :closed? ).and_return( false )
		
		lambda {
			@daemon.dispatch_to_handlers( client, [erroring_handler], request, response )
		}.should_not raise_error()
	end
	
	
	it "handles uncaught exceptions with a plain-text response if HTML isn't acceptable" do
		params    = {
			'HTTP_ACCEPT' => 'text/plain'
		}
		request   = mock( "mongrel request" )
		response  = mock( "mongrel response" )

		erroring_handler = mock( "buggy filter", :null_object => true )
		
		erroring_handler.should_receive( :process ).
			and_raise( RuntimeError.new("some error") )
		request.should_receive( :params ).at_least( :once ).
			and_return( params )

		response.should_receive( :write ).with( /500 internal server error/i )
		response.should_receive( :write ).with( %r{content-type: text/plain}i )
		response.should_receive( :write ).with( /some error/i )
		response.should_receive( :done= ).with( anything() )

		client = mock( "client object", :null_object => true )
		# BRANCH: client returns true
		client.should_receive( :closed? ).and_return( false )
		
		lambda {
			@daemon.dispatch_to_handlers( client, [erroring_handler], request, response )
		}.should_not raise_error()
	end
	

	it "handles uncaught request errors with a valid http BAD_REQUEST response" do
		params    = {
			'HTTP_ACCEPT' => 'text/plain'
		}
		request   = mock( "mongrel request" )
		response  = mock( "mongrel response" )

		erroring_handler = mock( "buggy filter", :null_object => true )
		
		erroring_handler.should_receive( :process ).
			and_raise( ThingFish::RequestError.new("bad client! no cupcake!") )
		request.should_receive( :params ).at_least( :once ).
			and_return( params )

		response.should_receive( :write ).with( /400 bad request/i )
		response.should_receive( :write ).with( %r{content-type: text/plain}i )
		response.should_receive( :write ).with( /bad client/i )
		response.should_receive( :done= ).with( anything() )

		client = mock( "client object", :null_object => true )
		client.should_receive( :closed? ).and_return( false )
		
		lambda {
			@daemon.dispatch_to_handlers( client, [erroring_handler], request, response )
		}.should_not raise_error()
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


describe ThingFish::Daemon, " constructed with no arguments" do

	before(:each) do
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )
		@daemon = ThingFish::Daemon.new
	end

	it "uses default config IP" do
		@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
	end

	it "uses default config port" do
		@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port])
	end
end


describe ThingFish::Daemon, " with a differing ip config" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.ip = TEST_IP

		# Gracefully handle the case where the testing host is already running 
		# something on the default port
		begin
			@daemon = ThingFish::Daemon.new( @config )
		rescue Errno::EADDRINUSE
			@daemon = nil
		end
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close if @daemon
	end


	it "binds to the test ip" do
		@daemon.host.should equal( TEST_IP) if @daemon
	end

	it "uses default config port" do
		@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port]) if @daemon
	end
end

describe ThingFish::Daemon, " started as root with a user configged" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.user = 'not-root'
		@daemon = ThingFish::Daemon.new( @config )
	end


	it "drops privileges" do
		Process.should_receive(:euid).at_least(:once).and_return(0)
	
		pwent = mock( 'not-root pw entry' ) 
		Etc.should_receive( :getpwnam ).with( @config.user ).and_return( pwent )
		pwent.should_receive( :uid ).and_return( 1000 )

		Process.should_receive( :euid= ).with( 1000 )
		@daemon.run
	end
end


describe ThingFish::Daemon, " with a differing port config" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.port = TEST_PORT
		@daemon = ThingFish::Daemon.new( @config )
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close
	end


	it "uses default config IP" do
		@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
	end

	it "binds to the test port" do
		@daemon.port.should equal( TEST_PORT)
	end
end


describe ThingFish::Daemon, " with an ip and host configured" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.ip = TEST_IP
		@config.port = TEST_PORT
		@daemon = ThingFish::Daemon.new( @config )
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close
	end


	it "binds to the test ip" do
		@daemon.host.should equal( TEST_IP)
	end

	it "binds to test port" do
		@daemon.port.should equal( TEST_PORT)
	end

end


describe ThingFish::Daemon, " with one or more handlers in its configuration" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.plugins.handlers = [
			{'test' => '/test' },
		]
		
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )
		@daemon = ThingFish::Daemon.new( @config )
	end

	it "registers its configured handlers" do
		@daemon.classifier.uris.length.should == 2
	end
	
end

describe ThingFish::Daemon, " (while running)" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.port = 7777
		@daemon = ThingFish::Daemon.new( @config )
		@acceptor = @daemon.run
	end

	it "stops executing when shut down" do
		@daemon.shutdown
		@acceptor.should_not be_alive
	end
end


# vim: set nosta noet ts=4 sw=4:
