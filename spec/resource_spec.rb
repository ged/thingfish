#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/constants'
	require 'thingfish'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


#####################################################################
###	E X A M P L E S
#####################################################################

describe ThingFish::Resource do
	include ThingFish::TestConstants

	before do
		@io = StringIO.new( TEST_CONTENT )
	end

	it "can be created from an IO" do
		resource = ThingFish::Resource.new( @io )
		resource.data.should == TEST_CONTENT
	end
	
	
	it "can be created with metadata" do
		resource = ThingFish::Resource.new( @io, :author => "Heidi Escariot" )
		resource.metadata[:author].should == "Heidi Escariot"
	end


	it "can be created with data in a String" do
		resource = ThingFish::Resource.new( TEST_CONTENT )
		resource.data.should == TEST_CONTENT
	end

	it "allows metadata to be fetched via attribute reader methods" do
		resource = ThingFish::Resource.new( @io, :format => 'text/html' )
		resource.format.should == 'text/html'
	end
	
	it "allows metadata to be set via attribute setter methods" do
		resource = ThingFish::Resource.new( @io )
		resource.format = 'text/html'
		resource.format.should == 'text/html'
	end
	
end

# vim: set nosta noet ts=4 sw=4:
