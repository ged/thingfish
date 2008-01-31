#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/json'
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
describe ThingFish::JSONFilter do
	
	TEST_JSON_CONTENT = TEST_RUBY_OBJECT.to_json

	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'json', {} )

		@request = mock( "request object" )
		@response = mock( "response object" )
		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )
	end

	after( :all ) do
		ThingFish.reset_logger
	end



	it_should_behave_like "A Filter"
	
	
	it "converts Ruby-object responses to JSON if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'application/json' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		@response.should_receive( :body ).and_return( TEST_RUBY_OBJECT )
		
		@response.should_receive( :body= ).with( TEST_JSON_CONTENT )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( 'application/json' )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the client doesn't accept JSON" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'application/json' ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the response isn't a Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'application/json' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'text/html' )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end


	it "doesn't propagate errors during JSON generation" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'application/json' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		erroring_object = mock( "ruby object that raises an error when converted to JSON" )
		@response.should_receive( :body ).
			at_least( :once ).
			and_return( erroring_object )
		
		erroring_object.should_receive( :to_json ).
			and_raise( "Oops, couldn't convert to JSON for some reason!" )
		
		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		lambda {
			@filter.handle_response( @response, @request )
		}.should_not raise_error()
	end
	

end

# vim: set nosta noet ts=4 sw=4:

