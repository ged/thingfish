#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'pathname'
require 'spec/runner'
require 'stringio'
require 'thingfish/constants'

require 'thingfish/handler/inspect'



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe "The inspection handler" do
	before(:all) do
		ThingFish.reset_logger
	end
	
	before(:each) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'inspect', 'resource_dir' => resdir )
		@request  = mock( "request", :null_object => true )
		@response = mock( "response", :null_object => true )
		@headers  = mock( "headers", :null_object => true )
		@out      = mock( "out", :null_object => true )
	end


	it "should return inspected objects" do
		@request.stub!( :pretty_print ).and_return( "PRETTYPRINTED REQUEST")
		@request.stub!( :body ).and_return( StringIO.new("BODY") )
		@headers.stub!( :pretty_print ).and_return( "PRETTYPRINTED HEADERS" )
		@response.stub!( :pretty_print ).and_return( "PRETTYPRINTED RESPONSE" )

		@response.should_receive( :start ).with( HTTP::OK ).
			and_yield( @headers, @out )
		@headers.should_receive( :[]= ).with( 'Content-Type', 'text/html' )
	    @out.should_receive( :write ).with( an_instance_of(String) )
		@handler.process( @request, @response )
	end

end

# vim: set nosta noet ts=4 sw=4:
