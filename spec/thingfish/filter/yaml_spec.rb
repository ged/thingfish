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
require 'thingfish/filter/yaml'



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
		setup_logging( :fatal )
	end

	let( :filter ) do
		ThingFish::Filter.create( 'yaml', {} )
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

		self.filter.handle_request( @request, @response )
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

		self.filter.handle_response( @response, @request )
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

		self.filter.handle_request( @request, @response )
	end


	it "does no conversion if the client doesn't accept YAML" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		self.filter.handle_response( @response, @request )
	end


	it "does no conversion if the response isn't a Ruby object" do
		@request.should_receive( :explicitly_accepts? ).
			with( 'text/x-yaml' ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( CONFIGURED_HTML_MIMETYPE )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		self.filter.handle_response( @response, @request )
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

		expect {
			self.filter.handle_response( @response, @request )
		}.to raise_error( YAML::ParseError, "couldn't parse it!" )
	end


end

# vim: set nosta noet ts=4 sw=4:
