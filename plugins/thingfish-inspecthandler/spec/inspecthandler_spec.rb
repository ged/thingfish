#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'pathname'
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/handler_behavior'

	require 'thingfish/constants'
	require 'thingfish/handler/inspect'
	require 'thingfish/exceptions'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::TestHelpers


#####################################################################
###	C O N T E X T S
#####################################################################

describe "The inspection handler" do
	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
	
	before(:each) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'inspect', 'resource_dir' => resdir )
		@request  = mock( "request", :null_object => true )
		@response = mock( "response", :null_object => true )

		@template = mock( "ERB template", :null_object => true )
		@handler.stub!( :get_erb_resource ).and_return( @template )

		@request_headers  = mock( "request headers", :null_object => true )
		@request.stub!( :headers ).and_return( @request_headers )
		@response_headers  = mock( "response headers", :null_object => true )
		@response.stub!( :headers ).and_return( @response_headers )
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	

	# Shared behaviors
	it_should_behave_like "A Handler"

	
	# Examples

	it "renders the template without an inspected object if there's nothing in the path_info" do
		@request.should_receive( :accepts? ).with( "text/html" ).and_return( true )
		@request.should_receive( :path_info ).and_return( "" )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@template.should_receive( :result ).and_return( :the_result )
		@response.should_receive( :body= ).with( :the_result )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a NOT_ACCEPTABLE response for anything other than requests for HTML" do
		@request.should_receive( :accepts? ).with( "text/html" ).and_return( false )
		@request_headers.should_receive( :[] ).with( :accept ).and_return( "chunky/peanutbutter" )
		lambda {
			@handler.handle_get_request( @request, @response )
		}.should raise_error( ThingFish::RequestError,
			%r{don't know how to satisfy a request for "chunky/peanutbutter"} )
	end
	
	
	it "renders the current daemon object if the path_info contains 'daemon'" do
		daemon = mock( "daemon", :null_object => true )
		@handler.listener = daemon

		@request.should_receive( :accepts? ).with( "text/html" ).and_return( true )
		@request.should_receive( :path_info ).and_return( "daemon" )

		daemon.should_receive( :html_inspect ).and_return( :the_html )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@template.should_receive( :result ).and_return( :the_result )
		@response.should_receive( :body= ).with( :the_result )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "renders the current request object if the path_info contains 'request'" do
		@request.should_receive( :accepts? ).with( "text/html" ).and_return( true )
		@request.should_receive( :path_info ).and_return( "request" )

		@request.should_receive( :html_inspect ).and_return( :the_html )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@template.should_receive( :result ).and_return( :the_result )
		@response.should_receive( :body= ).with( :the_result )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "renders the current response object if the path_info contains 'response'" do
		@request.should_receive( :accepts? ).with( "text/html" ).and_return( true )
		@request.should_receive( :path_info ).and_return( "response" )

		@response.should_receive( :html_inspect ).and_return( :the_html )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@template.should_receive( :result ).and_return( :the_result )
		@response.should_receive( :body= ).with( :the_result )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	
	
	
end

# vim: set nosta noet ts=4 sw=4:
