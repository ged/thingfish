#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/handler_behavior'
	require 'thingfish'
	require 'thingfish/handler'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants

# Expose some protected methods for testing
class ThingFish::Handler
	public :send_method_not_allowed_response
end

# Some subclasses just for testing
class TestHandler < ThingFish::Handler
	public :log_request
end

class GetDeleteTestHandler < ThingFish::Handler
	def handle_get_request( *args )
		return :get_response
	end
	
	def handle_delete_request( *args )
		return :delete_response
	end
end

include ThingFish::Constants


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::Handler do
	it "should register subclasses as plugins" do
		ThingFish::Handler.get_subclass( 'test' ).should == TestHandler
	end
end


describe ThingFish::Handler, " concrete subclass instance" do

	before(:each) do
	    @handler = ThingFish::Handler.create( 'test' )
		@datadir = Config::CONFIG['datadir']
	end


	### Shared behaviors
	it_should_behave_like "A Handler"


	### Specs
	it "knows what its normalized name is" do
		@handler.plugin_name.should == 'test'
	end


	it "outputs a consistent request log message" do
		logfile = StringIO.new('')
		ThingFish.logger = Logger.new( logfile )

		params = {
			'REQUEST_METHOD' => 'POST',
			'REMOTE_ADDR'    => '127.0.0.1',
			'REQUEST_URI'    => '/poon',
		}
		
		request = mock( "request object" )
		request.should_receive( :remote_addr ).
			at_least(:once).
			and_return( IPAddr.new('127.0.0.1') )
		request.should_receive( :http_method ).
			at_least(:once).
			and_return( 'POST' )
		request.should_receive( :uri ).
			at_least(:once).
			and_return( URI.parse('/poon')	)
		
		@handler.log_request( request )
		logfile.rewind
		logfile.read.should =~ %r{\S+: 127.0.0.1 POST /poon}
	end

	
	it "gets references to the metastore and filestore from the listener callback" do
		mock_listener = mock( "listener", :null_object => true )
		mock_listener.should_receive( :filestore ).and_return( :filestore_obj )
		mock_listener.should_receive( :metastore ).and_return( :metastore_obj )
		
		@handler.listener = mock_listener
	end


	it "doesn't add to the index content by default" do
		@handler.make_index_content( '/foo' ).should be_nil
	end

end


describe ThingFish::Handler, " that handles GET and DELETE requests" do

	before(:each) do
		ThingFish.logger.level = Logger::FATAL

		@request = mock( "request object", :null_object => true )
		@response = mock( "response object", :null_object => true )
		@response_headers = mock( "response headers", :null_object => true )

		@response.stub!( :headers ).and_return( @response_headers )

	    @handler = ThingFish::Handler.create( 'getdeletetest' )
		@datadir = Config::CONFIG['datadir']
	end


	### Shared behaviors
	it_should_behave_like "A Handler"


	### Specs
	
	it "should call its #handle_get_request method on a GET request" do
		@response.stub!( :handlers ).and_return( [] )
		@request.should_receive( :http_method ).
			at_least(:once).
			and_return( 'GET' )

		@handler.process( @request, @response ).should == :get_response
	end

	
	it "should call its #handle_get_request method on a HEAD request" do
		@response.stub!( :handlers ).and_return( [] )
		@request.should_receive( :http_method ).
			at_least(:once).
			and_return( 'HEAD' )

		@handler.process( @request, @response ).should == :get_response
	end

	
	it "should respond with a METHOD_NOT_ALLOWED response on a POST request" do
		@request.should_receive( :http_method ).
			at_least(:once).
			and_return( 'POST' )
		@handler.stub!( :methods ).
			and_return(['handle_get_request', 'handle_delete_request'])
		
		@response.should_receive( :status= ).
			with( HTTP::METHOD_NOT_ALLOWED )
		@response_headers.should_receive( :[]= ).
			with( :allow, 'DELETE, GET, HEAD' )
		@response.should_receive( :body= ).
			with( /POST.*not allowed/ )

		@handler.process( @request, @response )
	end
	

	it "should use a list of valid methods if one is provided" do
		@response.should_receive( :status= ).
			with( HTTP::METHOD_NOT_ALLOWED )
		@response_headers.should_receive( :[]= ).
			with( :allow, 'DELETE, GET, HEAD' )
		@response.should_receive( :body= ).
			with( /PUT.*not allowed/ )
		
		@handler.send_method_not_allowed_response( @response, 'PUT', %w{DELETE GET HEAD} )
	end


	it "should add HEAD to a list of provided methods if it includes 'GET'" do
		@response.should_receive( :status= ).
			with( HTTP::METHOD_NOT_ALLOWED )
		@response_headers.should_receive( :[]= ).
			with( :allow, 'DELETE, GET, HEAD' )
		@response.should_receive( :body= ).
			with( /PUT.*not allowed/ )
		
		@handler.send_method_not_allowed_response( @response, 'PUT', %w{DELETE GET} )
	end
end

# vim: set nosta noet ts=4 sw=4:
