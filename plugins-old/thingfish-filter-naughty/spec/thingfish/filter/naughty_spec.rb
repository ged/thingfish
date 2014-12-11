#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'
require 'spec/lib/filter_behavior'

require 'rbconfig'

require 'thingfish'
require 'thingfish/filter'
require 'thingfish/filter/naughty'



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe ThingFish::NaughtyFilter do

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end

	it "raises an error when enabled without the confirmation config key" do
		lambda {
			ThingFish::Filter.create( 'naughty' )
		}.should raise_error( RuntimeError )
	end

	### Implementation-specific Examples
	describe "enabled by the config" do

		before( :each ) do
			@filter = ThingFish::Filter.create( 'naughty',
				'enable' => 'yes, I understand this is just for testing')

			@request = mock( "request object" )
			@response = mock( "response object" )
			@response_headers = mock( "response headers" )
			@response.stub!( :headers ).and_return( @response_headers )
			@request_headers = mock( "request headers" )
			@request.stub!( :headers ).and_return( @request_headers )
		end

		### Shared behaviors
		it_should_behave_like "a filter"

		it "poops all over the request body IO handles" do
			body = mock( "A body object in the request" )

			@request.should_receive( :each_body ).and_yield( body, {} )
			body.should_receive( :read )
			body.should_receive( :close )

	   		@filter.handle_request( @request, @response )
		end
	end
end

# vim: set nosta noet ts=4 sw=4:
