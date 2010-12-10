#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/behavior/filter'
require 'thingfish/filter/ruby'


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::RubyFilter do

	TEST_MARSHALLED_CONTENT = Marshal.dump( ThingFish::TestConstants::TEST_RUBY_OBJECT )

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :filter ) do
		ThingFish::Filter.create( 'ruby', {} )
	end

	before( :each ) do
		@request = mock( "request object" )
		@response = mock( "response object" )
		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )
		@request_headers = mock( "request headers" )
		@request.stub!( :headers ).and_return( @request_headers )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like "a filter"


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

		self.filter.handle_request( @request, @response )
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

		self.filter.handle_response( @response, @request )
	end


	it "doesn't modify the request if there was a problem unmarshalling" do
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MARSHALLED_MIMETYPE )
		bodyio = StringIO.new( TEST_MARSHALLED_CONTENT )
		@request.should_receive( :body ).
			at_least( :once ).
			with( no_args() ).
			and_return( bodyio )

		Marshal.stub!( :load ).and_raise( ArgumentError.new("error parsing") )

		@request.should_not_receive( :body= )
		@request.should_not_receive( :content_type= )

		self.filter.handle_request( @request, @response )
	end


	it "does no conversion if the client doesn't accept marshalled Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )

		self.filter.handle_response( @response, @request )
	end


	it "does no conversion if the response isn't a Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).and_return( CONFIGURED_HTML_MIMETYPE )

		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )

		self.filter.handle_response( @response, @request )
	end


	it "propagates errors during marshalling" do
		@request.should_receive( :explicitly_accepts? ).
			with( RUBY_MARSHALLED_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		@response.should_receive( :body ).
			at_least( :once ).
			and_return( Proc.new {} )

		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= )

		expect {
			self.filter.handle_response( @response, @request )
		}.to raise_error( TypeError, /no marshal_dump/ )
	end


end

# vim: set nosta noet ts=4 sw=4:
