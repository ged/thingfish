#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'pathname'
require 'tmpdir'
require 'spec/runner'
require 'thingfish/constants'

require 'thingfish/filestore/<%= vars[:name] %>'



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants


FSFS_TEST_KEY  = '12ad84d8-bb95-11db-a22e-0017f2004c5e'
FSFS_TEST_KEY2 = '06363890-c67f-11db-84a0-b7f0d178e52d'
FSFS_TEST_DATA = 'test data'


context "A <%= vars[:name].capitalize %> FileStore" do

	setup do
	    @fs = ThingFish::FileStore.create( '<%= vars[:name] %>' )
		@io = StringIO.new( FSFS_TEST_DATA )
	end
	
	
	### Specs
	
	specify "returns nil for non-existant entry" do
	    @fs.fetch( FSFS_TEST_KEY ).should == nil
	end

	specify "returns data for existing entries via an IO" do
	    @fs.store_io( FSFS_TEST_KEY, @io )
		@fs.fetch_io( FSFS_TEST_KEY ) do |io|
			io.read.should == FSFS_TEST_DATA
		end
	end

	specify "returns data for existing entries via a String" do
		@fs.store( FSFS_TEST_KEY, FSFS_TEST_DATA )
		@fs.fetch( FSFS_TEST_KEY ).should == FSFS_TEST_DATA
	end

	specify "deletes requested items" do
		@fs.store( FSFS_TEST_KEY, FSFS_TEST_DATA )
		@fs.delete( FSFS_TEST_KEY ).should be_true
		@fs.fetch( FSFS_TEST_KEY ).should be_nil
	end

	specify "silently ignores deletes of non-existant keys" do
		@fs.delete( FSFS_TEST_KEY2 ).should be_false
	end
	
	specify "returns false when checking has_file? for a file it does not have" do
		@fs.has_file?( FSFS_TEST_KEY ).should be_false
	end

	specify "returns true when checking has_file? for a file it has" do
		@fs.store( FSFS_TEST_KEY, FSFS_TEST_DATA )
		@fs.has_file?( FSFS_TEST_KEY ).should be_true
	end

	specify "returns false when checking has_file? for a file which has been deleted" do
		@fs.store( FSFS_TEST_KEY, FSFS_TEST_DATA )
		@fs.delete( FSFS_TEST_KEY )
		@fs.has_file?( FSFS_TEST_KEY ).should be_false
	end
	
	specify "returns the size of an existing resource in bytes" do
		@fs.store( FSFS_TEST_KEY, FSFS_TEST_DATA )
		@fs.size( FSFS_TEST_KEY ).should == FSFS_TEST_DATA.length
	end

	specify "can calculate the size of all files stored in the filestore" do
		uuids = []
		10.times do
			uuid = UUID.timestamp_create
			uuids << uuid
			@fs.store( uuid, FSFS_TEST_DATA )
			@fs.total_size.should == uuids.nitems * FSFS_TEST_DATA.length
		end
	end
end

# vim: set nosta noet ts=4 sw=4:
