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
	require 'spec/lib/filestore_behavior'
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


describe ThingFish::MemoryFileStore do
	include ThingFish::TestConstants

	before(:each) do
	    @fs = ThingFish::FileStore.create( 'memory' )
		@io = StringIO.new( TEST_RESOURCE_CONTENT )
	end

	it_should_behave_like "A FileStore"

end

describe ThingFish::MemoryFileStore, " with a maxsize of 2k" do
	include ThingFish::TestConstants

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
