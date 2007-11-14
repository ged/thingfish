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
	require 'thingfish/filter/html'
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
describe ThingFish::HtmlFilter do
	
	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'html', {} )

		@request = mock( "request object" )
		@response = mock( "response object" )

		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )

		@first_handler = mock( "first handler" )
		@last_handler = mock( "last handler" )
		@response.stub!( :handlers ).and_return([ @first_handler, @last_handler ])
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	it_should_behave_like "A Filter"

	
	it "converts Ruby-object responses to HTML if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/html' ).
			and_return( true )
		@response_headers.should_receive( :[] ).
			with( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		body = mock( "response body" )
		@response.should_receive( :body ).and_return( body )
		@last_handler.should_receive( :make_html_content ).
			with( body, @request, @response ).
			and_return( :html )

		@response.should_receive( :body= ).with( :html )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the client doesn't accept HTML" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/html' ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end	
end

# vim: set nosta noet ts=4 sw=4:
