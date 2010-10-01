#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/handler_behavior'

require 'rbconfig'

require 'thingfish'
require 'thingfish/handler'


include ThingFish::TestConstants

# Expose some protected methods for testing
class ThingFish::Handler
	public :build_method_not_allowed_response
end

# Some subclasses just for testing
class TestHandler < ThingFish::Handler
	public :log_request
end

class GetDeleteTestHandler < ThingFish::Handler
	def handle_get_request( *args )
		return :get_response, args
	end

	def handle_delete_request( *args )
		return :delete_response, args
	end
end

include ThingFish::Constants


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::Handler do
	include ThingFish::SpecHelpers
	
	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

	
	it "should register subclasses as plugins" do
		ThingFish::Handler.get_subclass( 'test' ).should == TestHandler
	end


	describe "concrete subclass instance mounted at /" do

		before( :each ) do
		    @handler = ThingFish::Handler.create( 'test', '/' )
			@datadir = Config::CONFIG['datadir']
			
			@request = mock( "request object" )
			@response = mock( "response object" )
		end

		it "does not raise an exception when asked to create path_info for a request whose " +
		   "path is an empty string" do
			uri = URI.parse( 'http://thingfish.example.com:3474/')
			@request.should_receive( :uri ).at_least( :once ).and_return( uri )
			lambda {
				@handler.path_info( @request )
			}.should_not raise_error( ThingFish::DispatchError, %r{uri \S+ does not include}i )
		end
		

		it "delegation defaults to yielding back to the caller" do
			yielded = nil
			
			results = @handler.delegate( @request, @response ) do |*args|
				yielded = args
				[:other_request, :other_response]
			end
			
			yielded.should == [ @request, @response ]
			results.should == [ :other_request, :other_response ]
		end
	
	end

	describe "concrete subclass instance mounted at /test" do

		before( :each ) do
		    @handler = ThingFish::Handler.create( 'test', '/test' )
			@datadir = Config::CONFIG['datadir']
		end


		### Shared behaviors
		it_should_behave_like "A Handler"


		### Specs
		it "knows what its normalized name is" do
			@handler.plugin_name.should == 'test'
		end


		it "can return the request's path relative to itself" do
			uri = URI.parse( 'http://thingfish.example.com:3474/test/cranglock')
			request = mock( "request object" )
			request.should_receive( :uri ).and_return( uri )
			@handler.path_info( request ).should == 'cranglock'
		end


		it "doesn't include query arguments when determining path_info" do
			uri = URI.parse( 'http://thingfish.example.com:3474/test/cranglockin/around?plenty=true')
			request = mock( "request object" )
			request.should_receive( :uri ).and_return( uri )
			@handler.path_info( request ).should == 'cranglockin/around'
		end


		it "returns the empty string when asked to create path_info for a request whose URI " +
		   "path matches its own exactly" do
			uri = URI.parse( 'http://thingfish.example.com:3474/test')
			request = mock( "request object" )
			request.should_receive( :uri ).and_return( uri )
			@handler.path_info( request ).should == ''
		end		
		
		
		it "raises an exception when asked to create path_info for a request whose URI does not " +
		   "include the handler's mountpoint" do
			uri = URI.parse( 'http://thingfish.example.com:3474/crang/the/petite/weasel')
			request = mock( "request object" )
			request.should_receive( :uri ).at_least( :once ).and_return( uri )
			lambda {
				@handler.path_info( request )
			}.should raise_error( ThingFish::DispatchError, %r{uri \S+ does not include}i )
		end
		
		
		it "outputs a consistent request log message" do
			logfile = StringIO.new('')
			ThingFish.logger = Logger.new( logfile )

			params = {
				'REQUEST_METHOD' => :POST,
				'REMOTE_ADDR'    => '127.0.0.1',
				'REQUEST_URI'    => '/poon',
			}
			mockheaders = mock( "Mock Headers" )

			request = mock( "request object" )
			request.should_receive( :remote_addr ).
				at_least(:once).
				and_return( IPAddr.new('127.0.0.1') )
			request.should_receive( :http_method ).
				at_least(:once).
				and_return( :POST )
			request.should_receive( :uri ).
				at_least(:once).
				and_return( URI.parse('/poon')	)
			request.should_receive( :headers ).
				at_least(:once).
				and_return( mockheaders )

			mockheaders.should_receive( :user_agent ).
				and_return( "rspec/1.0" )

			@handler.log_request( request )
			logfile.rewind
			logfile.read.should =~ %r<\S+: 127.0.0.1 POST /poon \{rspec/1.0\}>
		end


		it "gets references to the metastore and filestore from the daemon startup callback" do
			mock_daemon = mock( "daemon", :null_object => true )
			mock_daemon.should_receive( :filestore ).and_return( :filestore_obj )
			mock_daemon.should_receive( :metastore ).and_return( :metastore_obj )

			@handler.on_startup( mock_daemon )
		end


		it "doesn't add to the index content by default" do
			@handler.make_index_content( '/foo' ).should be_nil
		end

	end


	describe "that handles GET and DELETE requests" do

		before(:each) do
			ThingFish.logger.level = Logger::FATAL

			@request = mock( "request object" )
			@request.stub!( :uri ).and_return( URI.parse('http://localhost/getdelete/something') )

			@response = mock( "response object" )
			@response_headers = mock( "response headers" )
			@response.stub!( :headers ).and_return( @response_headers )

		    @handler = ThingFish::Handler.create( 'getdeletetest', '/getdelete' )
			@datadir = Config::CONFIG['datadir']
		end


		### Shared behaviors
		it_should_behave_like "A Handler"


		### Specs

		it "calls its #handle_get_request method on a GET request" do
			@response.stub!( :handlers ).and_return( [] )
			@request.should_receive( :http_method ).
				at_least(:once).
				and_return( :GET )

			@handler.process( @request, @response ).
				should == [:get_response, ['something', @request, @response ]]
		end


		it "calls its #handle_get_request method on a HEAD request" do
			@response.stub!( :handlers ).and_return( [] )
			@request.should_receive( :http_method ).
				at_least(:once).
				and_return( :HEAD )

			@handler.process( @request, @response ).
				should == [:get_response, ['something', @request, @response ]]
		end


		it "responds with a METHOD_NOT_ALLOWED response on a POST request" do
			@request.should_receive( :http_method ).
				at_least(:once).
				and_return( :POST )
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


		it "uses a list of valid methods if one is provided" do
			@response.should_receive( :status= ).
				with( HTTP::METHOD_NOT_ALLOWED )
			@response_headers.should_receive( :[]= ).
				with( :allow, 'DELETE, GET, HEAD' )
			@response.should_receive( :body= ).
				with( /PUT.*not allowed/ )

			@handler.build_method_not_allowed_response( @response, :PUT, %w{DELETE GET HEAD} )
		end


		it "adds HEAD to a list of provided methods if it includes :GET" do
			@response.should_receive( :status= ).
				with( HTTP::METHOD_NOT_ALLOWED )
			@response_headers.should_receive( :[]= ).
				with( :allow, 'DELETE, GET, HEAD' )
			@response.should_receive( :body= ).
				with( /PUT.*not allowed/ )

			@handler.build_method_not_allowed_response( @response, :PUT, %w{DELETE GET} )
		end
	end
end

# vim: set nosta noet ts=4 sw=4:
