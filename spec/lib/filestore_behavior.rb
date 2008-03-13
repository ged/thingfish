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
	require 'thingfish/filestore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


describe "A FileStore", :shared => true do
	include ThingFish::TestConstants
	include ThingFish::SpecHelpers

	it "returns nil for non-existant entry" do
	    @fs.fetch( TEST_UUID ).should == nil
	end

	it "returns data for existing entries" do
	    @fs.store_io( TEST_UUID, @io )
		@fs.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "returns data for existing entries stored by UUID object" do
	    @fs.store_io( TEST_UUID_OBJ, @io )
		@fs.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "returns data for existing entries fetched by UUID object" do
	    @fs.store_io( TEST_UUID, @io )
		@fs.fetch_io( TEST_UUID_OBJ ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "deletes requested items" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.delete( TEST_UUID ).should be_true
		@fs.fetch( TEST_UUID ).should be_nil
	end

	it "deletes requested items by UUID object" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.delete( TEST_UUID_OBJ ).should be_true
		@fs.fetch( TEST_UUID ).should be_nil
	end

	it "silently ignores deletes of non-existant keys" do
		@fs.delete( 'porksausage' ).should be_false
	end
	
	it "returns false when checking has_file? for a file it does not have" do
		@fs.has_file?( TEST_UUID ).should be_false
	end

	it "returns true when checking has_file? for a file it has" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.has_file?( TEST_UUID ).should be_true
	end

	it "returns true when checking has_file? for a file it has by UUID object" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.has_file?( TEST_UUID_OBJ ).should be_true
	end

	it "returns false when checking has_file? for a file which has been deleted" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.delete( TEST_UUID )
		@fs.has_file?( TEST_UUID ).should be_false
	end

	it "knows what the size of any of its stored resources is" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.size( TEST_UUID ).should == TEST_RESOURCE_CONTENT.length
		@fs.size( TEST_UUID_OBJ ).should == TEST_RESOURCE_CONTENT.length
	end
	
	it "returns nil when asked for the size of a resource it doesn't contain" do
		@fs.size( TEST_UUID ).should be_nil
	end

end

