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
	require 'thingfish/filter/ruby'
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
describe ThingFish::RubyFilter do
	
	TEST_MARSHALLED_CONTENT = Marshal.dump( TEST_RUBY_OBJECT )

	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'ruby', {} )

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
	
	
	it "unmarshals Ruby-object requests if the content-type indicates it's a marshalled " +
	   "ruby object" do

		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MARSHALLED_MIMETYPE )
		@request.should_receive( :body ).
			with( no_args() ).
			and_return( TEST_MARSHALLED_CONTENT )

		@request.should_receive( :body= ).with( TEST_RUBY_OBJECT )
		@request.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		@filter.handle_request( @request, @response )
	end

	it "marshals Ruby-object responses if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		@response.should_receive( :body ).and_return( TEST_RUBY_OBJECT )
		
		@response.should_receive( :body= ).with( TEST_MARSHALLED_CONTENT )
		@response.should_receive( :content_type= ).with( RUBY_MARSHALLED_MIMETYPE )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the client doesn't accept marshalled Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the response isn't a Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).and_return( 'text/html' )

		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end


	it "doesn't propagate errors during marshalling" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		erroring_object = mock( "ruby object that raises an error when marshalled" )
		@response.should_receive( :body ).
			at_least( :once ).
			and_return( erroring_object )
		
		erroring_object.should_receive( :_dump ).
			and_raise( TypeError.new("Can't dump mock object") )
		
		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )

		lambda {
			@filter.handle_response( @response, @request )
		}.should_not raise_error()
	end
	

end

# vim: set nosta noet ts=4 sw=4:
