#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'pathname'
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/handler_behavior'

	require 'thingfish/constants'
	require 'thingfish/handler/inspect'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::TestHelpers


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
		@headers  = mock( "headers", :null_object => true )
		@out      = mock( "out", :null_object => true )
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	

	# Shared behaviors
	it_should_behave_like "A Handler"
	
	
	# Examples

	it "should return inspected objects" do
		params = {
			'REQUEST_METHOD' => 'GET',
			'REQUEST_URI'    => '/inspect',
			'PATH_INFO'      => '',
		}
		
		@request.stub!( :pretty_print ).and_return( "PRETTYPRINTED REQUEST")
		@request.stub!( :body ).and_return( StringIO.new("BODY") )
		@request.stub!( :params ).and_return( params )
		@headers.stub!( :pretty_print ).and_return( "PRETTYPRINTED HEADERS" )
		@response.stub!( :pretty_print ).and_return( "PRETTYPRINTED RESPONSE" )

		@response.should_receive( :start ).with( HTTP::OK, true ).
			and_yield( @headers, @out )
		@headers.should_receive( :[]= ).with( /Content-Type/i, 'text/html' )
	    @out.should_receive( :write ).with( an_instance_of(String) )
		@handler.process( @request, @response )
	end

end

# vim: set nosta noet ts=4 sw=4:
