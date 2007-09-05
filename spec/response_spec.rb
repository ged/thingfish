#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/response'
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

describe ThingFish::Response do
	include ThingFish::Constants

	before( :each ) do
		mongrel_response = stub( "mongrel response" )
		@response = ThingFish::Response.new( mongrel_response )
	end
	

	it "has some default headers" do
		@response.headers['Server'] == SERVER_SOFTWARE_DETAILS
	end

	it "can be reset to a pristine state" do
		@response.body << "Some stuff we want to get rid of later"
		@response.headers['x-lunch-packed-by'] = 'Your Mom'
		
		@response.reset
		
		@response.body.should == ''
		@response.headers.should have(1).keys
	end


	it "can find the length of its body if it's a String" do
		test_body = 'A string full of stuff'
		@response.body = test_body
		
		@response.get_content_length.should == test_body.length
	end


	it "knows if it has not yet been handled" do
		@response.should_not be_handled()
		@response.status = HTTP::OK
		@response.should be_handled()
	end


	it "can find the length of its body if it's an IO" do
		test_body_content = 'A string with some stuff in it'
		test_body = StringIO.new( test_body_content )
		@response.body = test_body
		
		@response.get_content_length.should == test_body_content.length
	end
	

	it "raises a descriptive error message if it can't get the body's length" do
		@response.body = Object.new
		
		lambda {
			@response.get_content_length
		}.should raise_error( ThingFish::ResponseError, /content length/i )
	end
	
end

# vim: set nosta noet ts=4 sw=4:
