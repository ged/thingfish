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
	
	TEST_YAML_CONTENT = TEST_RUBY_OBJECT.to_yaml

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
	end

	after( :all ) do
		ThingFish.reset_logger
	end

 :explicitly_accepts?

	it_should_behave_like "A Filter"
	
	
	it "converts Ruby-object responses to YAML if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response_headers.should_receive( :[] ).
			with( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		@response.should_receive( :body ).and_return( TEST_RUBY_OBJECT )
		
		@response.should_receive( :body= ).with( TEST_YAML_CONTENT )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/x-yaml' )
		
		@filter.handle_response( @response, @request )
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
		@response_headers.should_receive( :[] ).
			with( :content_type ).
			and_return( 'text/html' )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end


	it "doesn't propagate errors during YAML generation" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response_headers.should_receive( :[] ).
			with( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		erroring_object = mock( "ruby object that raises an error when converted to YAML" )
		@response.should_receive( :body ).
			at_least( :once ).
			and_return( erroring_object )
		
		erroring_object.should_receive( :to_yaml ).
			and_raise( "Oops, couldn't convert to YAML for some reason!" )
		
		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		lambda {
			@filter.handle_response( @response, @request )
		}.should_not raise_error()
	end
	

end

# vim: set nosta noet ts=4 sw=4:
