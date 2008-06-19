#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'

	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/filter_behavior'

	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/basicauth'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe ThingFish::BasicAuthFilter do
	include ThingFish::SpecHelpers

	AUTHENTICATE_HEADER = ThingFish::BasicAuthFilter::AUTHENTICATE_HEADER
	AUTHORIZATION_HEADER = ThingFish::BasicAuthFilter::AUTHORIZATION_HEADER

	TEST_VALID_USER = 'summer'
	TEST_VALID_PASS = 'glau'
	TEST_INVALID_CREDENTIALS = 'Basic ' + ['miscreant:marshgas'].pack('m').chomp
	TEST_UNSUPPORTED_CREDENTIALS = 'Glazzle ' + ["#{TEST_VALID_USER}:#{TEST_VALID_PASS}"].pack('m').chomp
	TEST_VALID_CREDENTIALS = 'Basic ' + ["#{TEST_VALID_USER}:#{TEST_VALID_PASS}"].pack('m').chomp


	before( :all ) do
		setup_logging( :fatal )
	end
	
	before( :each ) do
		users = { TEST_VALID_USER => TEST_VALID_PASS }
		uris = ['/protected']
		@filter = ThingFish::Filter.create( 'basicauth', 'users' => users, 'uris' => uris )
		@response = mock( "ThingFish::Response" )
		@request  = mock( "Thingfish::Request" )
		@response_headers = mock( "Response Headers" )
		@request_headers = mock( "Request Headers" )
		
		@request.stub!( :headers ).and_return( @request_headers )
		@response.stub!( :headers ).and_return( @response_headers )
	end

	after( :all ) do
		reset_logging()
	end
	

	### Shared behaviors
	it_should_behave_like "A Filter"


	### Implementation-specific Examples
	it "doesn't modify the request unless it completely matches one of the configured URIs" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/854908be-2cc8-11dd-a71b-870d8fb5ef1a' )

		@response_headers.should_not_receive( :[]= )
		@response.should_not_receive( :status= )
		@request.should_not_receive( :authed_user= )

		@filter.handle_request( @request, @response )
	end
	
	
	it "doesn't modify the request if its uri is incidentally similar to a protected one" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected_contrived' )

		@response_headers.should_not_receive( :[]= )
		@response.should_not_receive( :status= )
		@request.should_not_receive( :authed_user= )

		@filter.handle_request( @request, @response )
	end


	it "sets the response status to AUTH_REQUIRED if the request is for a protected uri" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected' )
		@request_headers.should_receive( :[] ).
			with( AUTHORIZATION_HEADER ).
			and_return( nil )
		@response.should_receive( :status= ).with( HTTP::AUTH_REQUIRED )
		@response_headers.should_receive( :[]= ).with( AUTHENTICATE_HEADER, /Basic realm="[^"]+"/ )

		@filter.handle_request( @request, @response )
	end


	it "sets the response status to AUTH_REQUIRED if the request is for a uri below a protected one" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected/admin/dump' )
		@request_headers.should_receive( :[] ).
			with( AUTHORIZATION_HEADER ).
			and_return( nil )
		@response.should_receive( :status= ).with( HTTP::AUTH_REQUIRED )
		@response_headers.should_receive( :[]= ).with( AUTHENTICATE_HEADER, /Basic realm="[^"]+"/ )

		@filter.handle_request( @request, @response )
	end


	it "sets the response status to AUTH_REQUIRED if the auth scheme isn't 'Basic'" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected' )
		@request_headers.should_receive( :[] ).with( AUTHORIZATION_HEADER ).
			and_return( TEST_UNSUPPORTED_CREDENTIALS )

		@request.should_not_receive( :authed_user= )

		@response.should_receive( :status= ).with( HTTP::AUTH_REQUIRED )
		@response_headers.should_receive( :[]= ).with( AUTHENTICATE_HEADER, /Basic realm="[^"]+"/ )

		@filter.handle_request( @request, @response )
	end
	

	it "sets the response status to AUTH_REQUIRED if the user provides invalid authentication" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected' )
		@request_headers.should_receive( :[] ).with( AUTHORIZATION_HEADER ).
			and_return( TEST_INVALID_CREDENTIALS )

		@response.should_receive( :status= ).with( HTTP::AUTH_REQUIRED )
		@response_headers.should_receive( :[]= ).with( AUTHENTICATE_HEADER, /Basic realm="[^"]+"/ )

		@filter.handle_request( @request, @response )
	end


	it "sets the authed user and doesn't change the response status if the user provides valid " +
	   "authentication" do
		@request.should_receive( :path ).at_least( :once ).
			and_return( '/protected' )
		@request_headers.should_receive( :[] ).with( AUTHORIZATION_HEADER ).
			and_return( TEST_VALID_CREDENTIALS )

		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		@request.should_receive( :authed_user= ).with( TEST_VALID_USER )

		@filter.handle_request( @request, @response )
	end
	

end

# vim: set nosta noet ts=4 sw=4:
