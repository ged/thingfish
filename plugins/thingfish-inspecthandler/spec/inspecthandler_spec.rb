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

		@request_headers  = mock( "request headers", :null_object => true )
		@request.stub!( :headers ).and_return( @request_headers )
		@response_headers  = mock( "response headers", :null_object => true )
		@response.stub!( :headers ).and_return( @response_headers )
		@response_data  = mock( "response data", :null_object => true )
		@response.stub!( :data ).and_return( @response_data )

		@daemon = mock( "daemon object", :null_object => true )
		@handler.listener = @daemon
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	

	# Shared behaviors
	it_should_behave_like "A Handler"

	
	# Examples

	it "responds with a Hash of supported objects for inspection if there's nothing in the path_info" do
		@request.should_receive( :path_info ).and_return( "" )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( an_instance_of(Hash) )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( @request, @response )
	end


	it "returns the current daemon object if the path_info contains 'daemon'" do
		@request.should_receive( :path_info ).and_return( "/daemon" )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @daemon )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "returns the current request object if the path_info contains 'request'" do
		@request.should_receive( :path_info ).and_return( "/request" )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @request )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "returns the current daemon object if the path_info contains 'response'" do
		@request.should_receive( :path_info ).and_return( "/response" )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @response )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "returns the current daemon's config object if the path_info contains '/config'" do
		@request.should_receive( :path_info ).and_return( "/config" )
		
		@daemon.should_receive( :config ).and_return( :the_config )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( :the_config )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "leaves the response status at the default for unsupported paths" do
		@request.should_receive( :path_info ).and_return( "/mudweasel/thermographics" )

		@response.should_not_receive( :status= )
		
		@handler.handle_get_request( @request, @response )
	end


	it "can make an HTML fragment out of the inspected object for the HTML filter" do
		body = mock( "body", :null_object => true )
		
		template = mock( "ERB template", :null_object => true )
		@handler.stub!( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).with( an_instance_of(Binding) ).and_return( :something )

		@handler.make_html_content( body, @request, @response ).should == :something
	end
	
	
end

# vim: set nosta noet ts=4 sw=4:
