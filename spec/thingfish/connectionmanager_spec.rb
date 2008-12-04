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

	require 'timeout'

	require 'thingfish'
	require 'thingfish/config'
	require 'thingfish/constants'
	require 'thingfish/request'
	require 'thingfish/connectionmanager'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestConstants
include ThingFish::Constants
include ThingFish::Constants::Patterns

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::ConnectionManager do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
		@socket  = mock( "A client socket" )
		@config  = ThingFish::Config.new
		@request = mock( "request object" )
		@conn = ThingFish::ConnectionManager.new( @socket, @config )
	end

	after( :all ) do
		reset_logging()
	end


	it "can return a human-readable description of itself suitable for debugging" do
		@socket.should_receive( :peeraddr ).any_number_of_times.
			and_return([ Socket::AF_INET, 1717, '208.77.188.166', 'host' ])
		@conn.instance_variable_set( :@pipeline_max, 100 )
		@conn.instance_variable_set( :@request_count, 8 )
		
		@conn.inspect.should =~ 
			%r{#<ThingFish::ConnectionManager:0x[[:xdigit:]]+ host:1717 \(8/100 requests\)>}
	end

	it "can return a human-readable description of itself suitable for logging" do
		@socket.should_receive( :peeraddr ).any_number_of_times.
			and_return([ Socket::AF_INET, 1717, '208.77.188.166', 'host' ])
		@conn.instance_variable_set( :@pipeline_max, 100 )
		@conn.instance_variable_set( :@request_count, 8 )
		
		@conn.session_info.should == "host:1717 (8/100 requests)"
	end

	### Read request

	describe "with a pending request" do

		before( :each ) do
			setup_logging( :fatal )
		end

		it "can read a GET request from its socket" do

			# simulating only part of the data being in the socket buffer the 
			# first time you go to read the socket
			halfway = TESTING_GET_REQUEST.length / 2
			chunker1, chunker2 = TESTING_GET_REQUEST[0..halfway], TESTING_GET_REQUEST[halfway + 1..-1]

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).twice.
				and_yield
			@socket.should_receive( :sysread ).with( @config.bufsize ).
				and_return( chunker1, chunker2 )
			ThingFish::Request.should_receive( :parse ).with( TESTING_GET_REQUEST, @config, @socket ).
				and_return( @request )
			@request.should_receive( :header ).at_least(:once).
				and_return({:content_length => nil})
			@request.should_receive( :body= ).with( nil )

			@conn.read_request.should == @request
		end


		it "returns a BAD_REQUEST response if a GET request has a body" do
			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).
				and_yield
			@socket.should_receive( :sysread ).with( @config.bufsize ).
				and_return( TESTING_GET_REQUEST )
			ThingFish::Request.should_receive( :parse ).with( TESTING_GET_REQUEST, @config, @socket ).
				and_return( @request )
			@request.should_receive( :header ).at_least(:once).
				and_return({:content_length => 11})
			@request.should_receive( :http_method ).at_least(:once).
				and_return( :GET )
			@request.should_not_receive( :body= )
			
			lambda {
				@conn.read_request
			}.should raise_error( ThingFish::RequestError, /GET method should not have an entity-body/ )
		end


		it "spools request body data into memory for requests whose body is within @memory_bodysize_max" do
			tempfile = mock( "Tempfile" )
			len = TEST_CONTENT.length
			first_half = TEST_CONTENT[ 0..len/2 ]
			second_half = TEST_CONTENT[ (len/2 + 1)..-1 ]

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).twice.
				and_yield

			@request.should_receive( :header ).at_least(:once).
				and_return({:content_length => len})
			@request.should_receive( :http_method ).and_return( :POST )

			Tempfile.should_not_receive( :new )
			StringIO.should_receive( :new ).and_return( tempfile )
			@socket.should_receive( :sysread ).with( an_instance_of(Fixnum) ).
				and_return( first_half, second_half + TESTING_GET_REQUEST[0..256] )

			tempfile.should_receive( :tell ).and_return( 0, 0, first_half.length, first_half.length, len )
			tempfile.should_receive( :write ).with( first_half ).and_return( first_half.length )
			tempfile.should_receive( :write ).with( second_half ).and_return( second_half.length )

			tempfile.should_receive( :rewind )

			@conn.read_request_body( @request )
			@conn.read_buffer.should == TESTING_GET_REQUEST[0..256]
		end

		it "spools request body data into a file for requests whose body exceeds @memory_bodysize_max" do
			@conn.instance_variable_set( :@memory_bodysize_max, 0 )

			tempfile = mock( "Tempfile" )
			len = TEST_CONTENT.length
			first_half = TEST_CONTENT[ 0..len/2 ]
			second_half = TEST_CONTENT[ (len/2 + 1)..-1 ]

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).twice.
				and_yield

			@request.should_receive( :header ).at_least(:once).
				and_return({:content_length => len})
			@request.should_receive( :http_method ).and_return( :POST )

			StringIO.should_not_receive( :new )
			Tempfile.should_receive( :new ).and_return( tempfile )
			tempfile.stub!( :path ).and_return( "/a/path/somewhere" )
			@socket.should_receive( :sysread ).with( an_instance_of(Fixnum) ).
				and_return( first_half, second_half + TESTING_GET_REQUEST[0..256] )

			tempfile.should_receive( :tell ).and_return( 0, 0, first_half.length, first_half.length, len )
			tempfile.should_receive( :write ).with( first_half ).and_return( first_half.length )
			tempfile.should_receive( :write ).with( second_half ).and_return( second_half.length )

			tempfile.should_receive( :rewind )

			@conn.read_request_body( @request )
			@conn.read_buffer.should == TESTING_GET_REQUEST[0..256]
		end
	end


	### Dispatch request
	describe "with a parsed request ready for dispatching" do

		before( :each ) do
			setup_logging( :fatal )

			@response = mock( "response object" )
			@response.stub!( :status_line ).and_return( "(debugging status line)" )
			@callback = stub( "daemon callback", :call => @response )
			@conn.instance_variable_set( :@dispatch_callback, @callback )
		end


		it "returns the response that is returned by the dispatch callback" do
			@response.should_receive( :is_handled? ).and_return( true )
			@response.should_receive( :body ).and_return( :the_body )
			@response.should_receive( :status_is_successful? ).and_return( true )
			@response.should_receive( :content_type ).
				at_least( :once ).
				and_return( :fancy_content_type )

			@request.stub!( :http_method )
			
			@request.should_receive( :accepts? ).with( :fancy_content_type ).
				and_return( true )

			@conn.dispatch_request( @request ).should == @response
		end

		it "returns a NOT_FOUND response if the response isn't handled" do
			err_response = mock( "error response object" )
			@response.should_receive( :is_handled? ).and_return( false )
			@conn.should_receive( :prepare_error_response ).
				with( @response, @request, HTTP::NOT_FOUND ).
				and_return( err_response )

			@request.stub!( :http_method )
			@request.stub!( :uri )

			@conn.dispatch_request( @request ).should == err_response
		end

		it "sets the content type to the default if none is set" do
			@response.should_receive( :is_handled? ).and_return( true )
			@response.should_receive( :body ).and_return( :the_body )
			@response.should_receive( :status_is_successful? ).and_return( true )
			@response.should_receive( :content_type ).and_return( nil, DEFAULT_CONTENT_TYPE )
			@response.should_receive( :content_type= ).with( DEFAULT_CONTENT_TYPE )

			@request.should_receive( :accepts? ).with( DEFAULT_CONTENT_TYPE ).
				and_return( true )

			@conn.dispatch_request( @request ).should == @response
		end

		it "returns a NOT_ACCEPTABLE response if the response is of a content-type that isn't " +
		   "supported by the client" do
			err_response = mock( "error response object" )
			@response.should_receive( :is_handled? ).and_return( true )
			@response.should_receive( :body ).and_return( :the_body )
			@response.should_receive( :status_is_successful? ).and_return( true )
			@response.should_receive( :content_type ).at_least( :once ).
				and_return( DEFAULT_CONTENT_TYPE )

			@request.should_receive( :accepted_types ).and_return([ :something, :something_else ])
			@request.should_receive( :accepts? ).with( DEFAULT_CONTENT_TYPE ).
				and_return( false )

			@conn.should_receive( :prepare_error_response ).
				with( @response, @request, HTTP::NOT_ACCEPTABLE ).
				and_return( err_response )

			@conn.dispatch_request( @request ).should == err_response
		end

		it "transforms request errors into error responses" do
			err_response = mock( "error response object" )
			exception = ThingFish::RequestEntityTooLargeError.new( "too big!" )
			erroring_dispatcher = lambda { raise exception }
			@conn.instance_variable_set( :@dispatch_callback, erroring_dispatcher )

			@conn.should_receive( :prepare_error_response ).
				with( @response, @request, HTTP::REQUEST_ENTITY_TOO_LARGE, exception ).
				and_return( err_response )

			@request.should_receive( :http_version ).and_return( 1.1 )
			ThingFish::Response.should_receive( :new ).with( 1.1, @config ).
				and_return( @response )

			res = nil
			lambda {
				res = @conn.dispatch_request( @request )
			}.should_not raise_error()

			res.should == err_response
		end

		it "transforms other exceptions into SERVER_ERROR responses" do
			err_response = mock( "error response object" )
			exception = NoMethodError.new( "I'm ded" )
			erroring_dispatcher = lambda { raise exception }
			@conn.instance_variable_set( :@dispatch_callback, erroring_dispatcher )

			@conn.should_receive( :prepare_error_response ).
				with( @response, @request, HTTP::SERVER_ERROR, exception ).
				and_return( err_response )

			@request.should_receive( :http_version ).and_return( 1.1 )
			ThingFish::Response.should_receive( :new ).with( 1.1, @config ).and_return( @response )

			res = nil
			lambda {
				res = @conn.dispatch_request( @request )
			}.should_not raise_error()

			res.should == err_response
		end
	end


	describe "handling an error case" do

		before( :each ) do
			setup_logging( :fatal )

			@response = mock( "response object" )
			@response.stub!( :status_line ).and_return( "(debugging status line)" )
		end

		it "outputs a stacktrace when called with an exception" do
			exception = mock( "raised exception" )
			exception.should_receive( :message ).and_return( :an_exception_message )
			exception.should_receive( :backtrace ).and_return([ "a chunker", "another chunker" ])
			@response.should_receive( :handlers ).at_least( :once ).
				and_return([ :handler_one, :handler_two ])
			@response.should_receive( :reset )
			@response.should_receive( :status= ).with( HTTP::SERVER_ERROR )

			@request.should_receive( :accepts? ).with( CONFIGURED_HTML_MIMETYPE ).
				and_return( false )

			@response.should_receive( :content_type= ).with( 'text/plain' )
			@response.should_receive( :body= ).with( /500 \(Internal Server Error\)/ )

			response_body = mock( "the response body" )
			@response.should_receive( :body ).and_return( response_body )
			response_body.should_receive( :<< ).at_least( :twice ).and_return( response_body )

			@conn.prepare_error_response( @response, @request, HTTP::SERVER_ERROR, exception )
		end

		it "outputs an HTML error page if the client groks HTML" do
			@response.should_receive( :reset )
			@response.should_receive( :status= ).with( HTTP::REQUEST_ENTITY_TOO_LARGE )

			@request.should_receive( :accepts? ).with( CONFIGURED_HTML_MIMETYPE ).
				and_return( true )

			@response.should_receive( :content_type= ).with( CONFIGURED_HTML_MIMETYPE )
			@response.should_receive( :data ).at_least( :twice ).and_return({})

			# Load the specific content template for the type of response
			err_template = mock( "error response template" )
			@conn.should_receive( :get_error_response_template ).
				with( HTTP::REQUEST_ENTITY_TOO_LARGE ).
				and_return( err_template )

			# Load the wrapper template
			main_template = mock( "main template" )
			@conn.should_receive( :get_erb_resource ).with( 'template.rhtml' ).
				and_return( main_template )

			# Bind the two templates and insert them 
			err_template.should_receive( :result ).with( an_instance_of(Binding) )
			main_template.should_receive( :result ).with( an_instance_of(Binding) ).
				and_return( :the_html_output )

			@response.should_receive( :body= ).with( :the_html_output )

			@conn.prepare_error_response( @response, @request, HTTP::REQUEST_ENTITY_TOO_LARGE )
			
		end
		
		it "outputs a text error page if the client doesn't grok HTML" do
			@response.should_receive( :reset )
			@response.should_receive( :status= ).with( HTTP::SERVER_ERROR )

			@request.should_receive( :accepts? ).with( CONFIGURED_HTML_MIMETYPE ).
				and_return( false )

			@response.should_receive( :content_type= ).with( 'text/plain' )
			@response.should_receive( :body= ).with( /500 \(Internal Server Error\)/ )

			response_body = mock( "the response body" )
			@response.should_receive( :body ).and_return( response_body )
			response_body.should_receive( :<< ).at_least( :twice ).and_return( response_body )

			@conn.prepare_error_response( @response, @request, HTTP::SERVER_ERROR )
		end
		
		
		it "can load an error template for a specific HTTP error status (e.g., 404) if it exists" do
			@conn.should_receive( :resource_exists? ).with( "errors/404.rhtml" ).and_return( true )
			@conn.should_receive( :get_erb_resource ).with( "errors/404.rhtml" ).and_return( :the_404_template )
			@conn.get_error_response_template( HTTP::NOT_FOUND ).should == :the_404_template
		end
		
		it "can load an error template for a general HTTP error status (e.g., 400) if it exists" do
			@conn.should_receive( :resource_exists? ).with( "errors/404.rhtml" ).and_return( false )
			@conn.should_receive( :resource_exists? ).with( "errors/400.rhtml" ).and_return( true )
			@conn.should_receive( :get_erb_resource ).with( "errors/400.rhtml" ).and_return( :the_400_template )
			@conn.get_error_response_template( HTTP::NOT_FOUND ).should == :the_400_template
		end
		
		it "falls back to a generic template if there isn't a template for the HTTP error status" do
			@conn.should_receive( :resource_exists? ).with( "errors/404.rhtml" ).and_return( false )
			@conn.should_receive( :resource_exists? ).with( "errors/400.rhtml" ).and_return( false )
			@conn.should_receive( :resource_exists? ).with( "errors/generic.rhtml" ).and_return( true )
			@conn.should_receive( :get_erb_resource ).with( "errors/generic.rhtml" ).
				and_return( :the_generic_template )
			@conn.get_error_response_template( HTTP::NOT_FOUND ).should == :the_generic_template
		end
		
		it "returns nil if the generic template cannot be found" do
			@conn.should_receive( :resource_exists? ).with( "errors/404.rhtml" ).and_return( false )
			@conn.should_receive( :resource_exists? ).with( "errors/400.rhtml" ).and_return( false )
			@conn.should_receive( :resource_exists? ).with( "errors/generic.rhtml" ).and_return( false )
			@conn.should_not_receive( :get_erb_resource )
			@conn.get_error_response_template( HTTP::NOT_FOUND ).should == nil
		end
	end


	### Response write
	describe "with a response" do

		before( :each ) do
			setup_logging( :fatal )

			@response = mock( "response object" )
		end

		it "write the body for a response to a GET that contains an IO" do
			status_line = "HTTP/1.1 200 OK"
			header_data = "Header: data"
			@response.should_receive( :status_line ).and_return( status_line )
			@response.should_receive( :header_data ).and_return( header_data )

			@request.should_receive( :http_method ).and_return( :GET )
			
			io = mock( "IO object" )
			@response.should_receive( :body ).and_return( io, io )
			io.should_receive( :respond_to? ).with( :eof? ).and_return( true )

			len = TEST_CONTENT.length
			first_half = TEST_CONTENT[ 0..len/2 ]
			second_half = TEST_CONTENT[ (len/2 + 1)..-1 ]

			io.should_receive( :read ).with( an_instance_of(Fixnum) ).
				and_return( first_half, second_half )

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).twice.
				and_yield

			first_chunker = status_line + EOL + 
				header_data + EOL +
				first_half
			@socket.should_receive( :syswrite ).with( first_chunker ).
				and_return( first_chunker.length )
			@socket.should_receive( :syswrite ).with( second_half ).
				and_return( second_half.length )

			io.should_receive( :eof? ).and_return( false, false, false, true )

			@conn.write_response( @response, @request )
		end

		it "does not write the body for a response to a HEAD" do
			status_line = "HTTP/1.1 200 OK"
			header_data = "Header: data"
			@response.should_receive( :status_line ).and_return( status_line )
			@response.should_receive( :header_data ).and_return( header_data )

			@request.should_receive( :http_method ).and_return( :HEAD )

			@response.should_not_receive( :body )

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).once.
				and_yield

			first_chunker = status_line + EOL +
			 	header_data + EOL
			@socket.should_receive( :syswrite ).with( first_chunker ).
				and_return( first_chunker.length )

			@conn.write_response( @response, @request )
		end

		it "writes the body for a response that contains a non-IO object" do
			status_line = "HTTP/1.0 200 OK"
			header_data = "Header: data"
			@response.should_receive( :status_line ).and_return( status_line )
			@response.should_receive( :header_data ).and_return( header_data )

			@request.should_receive( :http_method ).and_return( :GET )

			obj = mock( "non-IO object" )
			@response.should_receive( :body ).twice.and_return( obj )
			obj.should_receive( :respond_to? ).with( :eof? ).and_return( false )
			obj.should_receive( :to_s ).and_return( :the_stringified_object )

			io = mock( "StringIO wrapper" )
			StringIO.should_receive( :new ).with( :the_stringified_object ).and_return( io )

			len = TEST_CONTENT.length
			first_half = TEST_CONTENT[ 0..len/2 ]
			second_half = TEST_CONTENT[ (len/2 + 1)..-1 ]

			io.should_receive( :read ).with( an_instance_of(Fixnum) ).
				and_return( first_half, second_half )

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).twice.
				and_yield

			first_chunker = status_line + EOL + 
				header_data + EOL +
				first_half
			@socket.should_receive( :syswrite ).with( first_chunker ).
				and_return( first_chunker.length )
			@socket.should_receive( :syswrite ).with( second_half ).
				and_return( second_half.length )

			io.should_receive( :eof? ).and_return( false, false, false, true )

			@conn.write_response( @response, @request )
		end
		
		it "closes the connection if either the request or response indicate that it should close" do
			@conn.should_receive( :read_request ).once.and_return( @request )
			@conn.should_receive( :dispatch_request ).with( @request ).once.and_return( @response )
			@conn.should_receive( :write_response ).with( @response, @request ).once
			
			@request.should_receive( :keepalive? ).and_return( true )
			@response.should_receive( :keepalive? ).and_return( false )

			@socket.should_receive( :close ).once
			@socket.stub!( :peeraddr ).and_return( [] )
			
			Timeout.timeout( 1 ) do
				@conn.process
			end
		end

		it "closes the connection if request count exceeds pipeline max" do
			@config.pipeline_max = 2
			@conn.instance_variable_set( :@request_count, 1 )
			
			@conn.should_receive( :read_request ).once.and_return( @request )
			@conn.should_receive( :dispatch_request ).with( @request ).once.and_return( @response )
			@conn.should_receive( :write_response ).with( @response, @request ).once
			
			@socket.should_receive( :close ).once
			@socket.stub!( :peeraddr ).and_return( [] )
			
			Timeout.timeout( 1 ) do
				@conn.process
			end
		end
		
		it "closes the connection on connection timeouts" do
			@socket.should_receive( :close ).once
			@socket.stub!( :peeraddr ).and_return( [] )

			Timeout.should_receive( :timeout ).with( @config.connection_timeout ).
				and_raise( TimeoutError.new("timeout") )

			@conn.process
		end
				
		it "processes another request if both the request and response have pipelining enabled" do
			@conn.should_receive( :read_request ).twice.and_return( @request )
			@conn.should_receive( :dispatch_request ).with( @request ).twice.and_return( @response )
			@conn.should_receive( :write_response ).with( @response, @request ).twice
			
			@request.should_receive( :keepalive? ).and_return( true, true )
			@response.should_receive( :keepalive? ).and_return( true, false )

			@socket.should_receive( :close ).once
			@socket.stub!( :peeraddr ).and_return( [] )
			
			Timeout.timeout( 1 ) do
				@conn.process
			end
		end
	end
end


# vim: set nosta noet ts=4 sw=4:
