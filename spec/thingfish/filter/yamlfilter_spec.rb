#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/yaml'
	require 'spec/lib/filter_behavior'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::YAMLFilter do
	
	TEST_YAML_CONTENT = <<-EO_YAML
	--- 
	- ip_address: 127.0.0.1
	- pine_cone: sandwiches
	- olive_oil: pudding
	EO_YAML

	TEST_YAML_CONTENT.gsub!( /^\s+/, '' )
	TEST_UNYAMLIFIED_CONTENT = YAML.load(TEST_YAML_CONTENT)


	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'yaml', {} )

		@request = mock( "request object" )
		@response = mock( "response object" )
		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )
		@request_headers = mock( "request headers" )
		@request.stub!( :headers ).and_return( @request_headers )
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	it_should_behave_like "A Filter"
	
	
	it "converts a request body into a Ruby object if the content-type indicates " +
	   "it's YAML" do
   		@request.should_receive( :content_type ).
   			at_least( :once ).
   			and_return( 'text/x-yaml' )
		bodyio = StringIO.new( TEST_YAML_CONTENT )
   		@request.should_receive( :body ).
   			at_least( :once ).
   			with( no_args() ).
   			and_return( bodyio )
   			
   		@request.should_receive( :body= ).with( TEST_UNYAMLIFIED_CONTENT )
   		@request.should_receive( :content_type= ).with( RUBY_MIMETYPE )
   			
   		@filter.handle_request( @request, @response )
   	end


	it "converts Ruby-object responses to YAML if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		@response.should_receive( :body ).and_return( TEST_RUBY_OBJECT )
		
		@response.should_receive( :body= ).with( TEST_YAML_CONTENT )
		# Conversion filters shouldn't change the status of the response even when successful.
		@response.should_not_receive( :status= )
		@response.should_receive( :content_type= ).with( 'text/x-yaml' )
   		
		@filter.handle_response( @response, @request )
	end


	it "doesn't modify the request if there was a problem parsing YAML" do
   		@request.should_receive( :content_type ).
   			at_least( :once ).
   			and_return( 'text/x-yaml' )
		bodyio = StringIO.new( TEST_YAML_CONTENT )
   		@request.should_receive( :body ).
   			at_least( :once ).
   			with( no_args() ).
   			and_return( bodyio )

		YAML.stub!( :load ).and_raise( YAML::ParseError.new("error parsing") )
   	
		@request.should_not_receive( :body= )
   		@request.should_not_receive( :content_type= )
   			
   		@filter.handle_request( @request, @response )
   	end

	
	it "does no conversion if the client doesn't accept YAML" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the response isn't a Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( XHTML_MIMETYPE )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end


	it "propagates errors during YAML generation" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		# This way of raising is really lame, as it's not really simulating
		# an error thrown from the YAML generation itself, but since that happens
		# on a stringified object, we can't really simulate this without doing
		# some nasty partial stub on the object under test, which is (IMO)
		# even more lame.
		@response.should_receive( :body ).
			once.
			and_raise( YAML::ParseError.new("couldn't parse it!") )
		
		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		lambda {
			@filter.handle_response( @response, @request )
		}.should raise_error()
	end
	

end

# vim: set nosta noet ts=4 sw=4:
