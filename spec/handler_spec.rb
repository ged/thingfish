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

class TestHandler < ThingFish::Handler
	public :log_request
end

class GetHeadTestHandler < ThingFish::Handler
	def handle_get_request( *args )
		return :get_response
	end
	
	def handle_head_request( *args )
		return :head_response
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


	### Specs
	it "knows what its normalized name is" do
		@handler.plugin_name.should == 'testhandler'
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
		request.should_receive( :params ).at_least(1).and_return( params )
		
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


describe ThingFish::Handler, " that handles GET and HEAD requests" do

	before(:each) do
	    @handler = ThingFish::Handler.create( 'getheadtest' )
		@datadir = Config::CONFIG['datadir']
	end


	### Specs
	
	it "should call its #handle_get_request method on a GET request" do
		params = {
			'REQUEST_METHOD' => 'GET',
			'REMOTE_ADDR'    => '127.0.0.1',
			'REQUEST_URI'    => '/spoon',
		}
		
		request = mock( "request object" )
		response = stub( "response object", :header => {} )
		
		request.should_receive( :params ).at_least(1).and_return( params )

		@handler.process( request, response ).should == :get_response
	end

	
	it "should respond with a METHOD_NOT_ALLOWED response on a POST request" do
		params = {
			'REQUEST_METHOD' => 'POST',
			'REMOTE_ADDR'    => '127.0.0.1',
			'REQUEST_URI'    => '/spoon',
		}
		
		request = mock( "request object" )
		response = mock( "response object", :null_object => true )
		outhandle = mock( "output filehandle" )
		headers = mock( "response headers", :null_object => true )

		request.should_receive( :params ).at_least(1).and_return( params )
		response.
			should_receive( :start ).
			with( HTTP::METHOD_NOT_ALLOWED, true ).
			and_yield( headers, outhandle )
		headers.
			should_receive( :[]= ).
			with( 'Allow', 'GET, HEAD' )
		outhandle.
			should_receive( :write ).
			with( /POST.*not allowed/ )
		
		@handler.process( request, response )
	end
	
end

# vim: set nosta noet ts=4 sw=4:
