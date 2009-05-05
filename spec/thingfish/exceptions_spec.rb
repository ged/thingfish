#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

begin
	require 'stringio'
	require 'spec'
	require 'spec/lib/helpers'
	require 'spec/lib/constants'

	require "thingfish/exceptions"
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::SpecHelpers


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::RequestError do
	include ThingFish::Constants

	before( :each ) do
		@exception = ThingFish::RequestError.new( "oops" )
	end

	it "knows that its status is BAD_REQUEST" do
		@exception.status.should == HTTP::BAD_REQUEST
	end
end


describe ThingFish::RequestEntityTooLargeError do
	include ThingFish::Constants

	before( :each ) do
		@exception = ThingFish::RequestEntityTooLargeError.new( "oops" )
	end

	it "knows that its status is REQUEST_ENTITY_TOO_LARGE" do
		@exception.status.should == HTTP::REQUEST_ENTITY_TOO_LARGE
	end
end


describe ThingFish::RequestNotAcceptableError do
	include ThingFish::Constants

	before( :each ) do
		@exception = ThingFish::RequestNotAcceptableError.new( "oops" )
	end

	it "knows that its status should be NOT_ACCEPTABLE" do
		@exception.status.should == HTTP::NOT_ACCEPTABLE
	end
end


