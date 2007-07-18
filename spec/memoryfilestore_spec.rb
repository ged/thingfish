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
	require 'thingfish/exceptions'
	require 'thingfish/filestore/memory'
	require 'stringio'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants

describe ThingFish::MemoryFileStore do

	before(:all) do
		@uuid = UUID.parse( TEST_UUID )
	end

	before(:each) do
	    @fs = ThingFish::FileStore.create( 'memory' )
		@io = StringIO.new( TEST_CONTENT )
	end

	it "returns nil for non-existant entry" do
	    @fs.fetch( TEST_UUID ).should == nil
	end

	it "returns data for existing entries" do
	    @fs.store_io( TEST_UUID, @io )
		@fs.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_CONTENT
		end
	end

	it "returns data for existing entries stored by UUID object" do
	    @fs.store_io( @uuid, @io )
		@fs.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_CONTENT
		end
	end

	it "returns data for existing entries fetched by UUID object" do
	    @fs.store_io( TEST_UUID, @io )
		@fs.fetch_io( @uuid ) do |io|
			io.read.should == TEST_CONTENT
		end
	end

	it "deletes requested items" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.delete( TEST_UUID ).should be_true
		@fs.fetch( TEST_UUID ).should be_nil
	end

	it "deletes requested items by UUID object" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.delete( @uuid ).should be_true
		@fs.fetch( TEST_UUID ).should be_nil
	end

	it "silently ignores deletes of non-existant keys" do
		@fs.delete( 'porksausage' ).should be_false
	end
	
	it "returns false when checking has_file? for a file it does not have" do
		@fs.has_file?( TEST_UUID ).should be_false
	end

	it "returns true when checking has_file? for a file it has" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.has_file?( TEST_UUID ).should be_true
	end

	it "returns true when checking has_file? for a file it has by UUID object" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.has_file?( @uuid ).should be_true
	end

	it "returns false when checking has_file? for a file which has been deleted" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.delete( TEST_UUID )
		@fs.has_file?( TEST_UUID ).should be_false
	end

	it "knows what the size of any of its stored resources is" do
		@fs.store( TEST_UUID, TEST_CONTENT )
		@fs.size( TEST_UUID ).should == TEST_CONTENT.length
		@fs.size( @uuid ).should == TEST_CONTENT.length
	end
	
	it "returns nil when asked for the size of a resource it doesn't contain" do
		@fs.size( TEST_UUID ).should be_nil
	end
	

end

describe ThingFish::MemoryFileStore, " with a maxsize of 2k" do
	before(:each) do
		@fs = ThingFish::FileStore.create( 'memory', :maxsize => 2_048 )
	end
	
	it "raises a FileStoreQuotaError when trying to store data > 3k" do
		lambda {
			@fs.store( TEST_UUID, '8=D' * 1024 )
		}.should raise_error( ThingFish::FileStoreQuotaError)
	end

	it "raises a FileStoreQuotaError when trying to store two things whose sum is > 2k" do
		@fs.store( TEST_UUID, '!' * 1024 )
		lambda {
			@fs.store( TEST_UUID2, '!' * 1025 )
		}.should raise_error( ThingFish::FileStoreQuotaError)
	end
	
	it "is able to store a 1k chunk of data" do
		lambda {
			@fs.store( TEST_UUID, '!' * 1024 )
		}.should_not raise_error
	end
end


# vim: set nosta noet ts=4 sw=4:
