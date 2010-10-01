#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/handler_behavior'

require 'pathname'
require 'stringio'

require 'thingfish/constants'
require 'thingfish/handler/inspect'
require 'thingfish/exceptions'


include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::SpecHelpers


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
		@handler.on_startup( @daemon )
	end

	after( :all ) do
		ThingFish.reset_logger
	end



	# Shared behaviors
	it_should_behave_like "A Handler"


	# Examples

	it "responds with a Hash of supported objects for inspection if there's nothing in the path_info" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( an_instance_of(Hash) )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( '', @request, @response )
	end


	it "returns the current daemon object if the path_info contains 'daemon'" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @daemon )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( '/daemon', @request, @response )
	end

	it "returns the current request object if the path_info contains 'request'" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @request )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( '/request', @request, @response )
	end

	it "returns the current daemon object if the path_info contains 'response'" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( @response )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( '/response', @request, @response )
	end

	it "returns the current daemon's config object if the path_info contains '/config'" do
		@daemon.should_receive( :config ).and_return( :the_config )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( :the_config )
		@response_data.should_receive( :[]= ).with( :tagline, an_instance_of(String) )
		@response_data.should_receive( :[]= ).with( :title, an_instance_of(String) )

		@handler.handle_get_request( '/config', @request, @response )
	end

	it "leaves the response status at the default for unsupported paths" do
		@response.should_not_receive( :status= )
		@handler.handle_get_request( "/mudweasel/thermographics", @request, @response )
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
