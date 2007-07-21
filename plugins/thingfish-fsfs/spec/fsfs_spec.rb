#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'pathname'
	require 'tmpdir'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/filestore_behavior'
	require 'thingfish/constants'
	require 'thingfish/filestore/filesystem'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################


describe "A Filesystem FileStore" do

	before(:all) do
		@tmpdir = make_tempdir()
	end

	before(:each) do
	    @fs = ThingFish::FileStore.create( 'filesystem', :root => @tmpdir.to_s )
		@io = StringIO.new( TEST_RESOURCE_CONTENT )
	end
	
	after(:each) do
		@tmpdir.rmtree
	end


	### Behaviors
	
	it_should_behave_like "A FileStore"
	
	
	### Specs
	
	it "returns nil for non-existant entry" do
	    @fs.fetch( TEST_UUID ).should == nil
	end

	it "returns data for existing entries via an IO" do
	    @fs.store_io( TEST_UUID, @io )
		@fs.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "propagates errors during a file upload" do
		ThingFish.logger.level = Logger::FATAL
		@io.stub!( :read ).and_return { raise Errno::ECONNRESET }

		lambda {
			@fs.store_io( TEST_UUID, @io )
		}.should raise_error( Errno::ECONNRESET )
		ThingFish.reset_logger
	end

	it "cleans up after itself on upload errors" do
		ThingFish.logger.level = Logger::FATAL
		@io.stub!( :read ).and_return { raise Errno::ECONNRESET }

		spooldir = @tmpdir + ThingFish::FilesystemFileStore::DEFAULT_SPOOLDIR
		spoolfile = spooldir + TEST_UUID
		spoolfile.unlink if spoolfile.exist?

		begin
			@fs.store_io( TEST_UUID, @io )
		rescue Errno::ECONNRESET
			# no op
		end
		
		spoolfile.exist?.should be_false

		ThingFish.reset_logger
	end

	it "returns data for existing entries via a String" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.fetch( TEST_UUID ).should == TEST_RESOURCE_CONTENT
	end

	it "deletes requested items" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.delete( TEST_UUID ).should be_true
		@fs.fetch( TEST_UUID ).should be_nil
	end

	it "silently ignores deletes of non-existant keys" do
		@fs.delete( TEST_UUID2 ).should be_false
	end
	
	it "returns false when checking has_file? for a file it does not have" do
		@fs.has_file?( TEST_UUID ).should be_false
	end

	it "returns true when checking has_file? for a file it has" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.has_file?( TEST_UUID ).should be_true
	end

	it "returns false when checking has_file? for a file which has been deleted" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.delete( TEST_UUID )
		@fs.has_file?( TEST_UUID ).should be_false
	end
	
	it "returns the size of an existing resource in bytes" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		@fs.size( TEST_UUID ).should == TEST_RESOURCE_CONTENT.length
	end

	it "can calculate the size of all files stored in the filestore" do
		uuids = []
		10.times do
			uuid = UUID.timestamp_create
			uuids << uuid
			@fs.store( uuid, TEST_RESOURCE_CONTENT )
			@fs.total_size.should == uuids.nitems * TEST_RESOURCE_CONTENT.length
		end
	end
	
	it "returns an MD5 sum of data upon storing it" do
		@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT ).should ==
			Digest::MD5.hexdigest( TEST_RESOURCE_CONTENT )
	end
	
	it "returns an MD5 sum of data upon uploading it via a socket" do
		@fs.store_io( TEST_UUID, @io ).should ==
			Digest::MD5.hexdigest( TEST_RESOURCE_CONTENT )
	end
end


describe "A Filesystem FileStore with a hash depth of 2" do

	before(:each) do
	    @fs = ThingFish::FileStore.create( 'filesystem', :hashdepth => 2, :root => '.' )
		@io = StringIO.new( TEST_RESOURCE_CONTENT )
	end


	it "uses a path with 2 subdirectories" do
		@fs.send( :hashed_path, TEST_UUID ).should ==
			Pathname.new( File.join('.', '60ac', 'c01e', TEST_UUID) )
	end
end


describe "A Filesystem FileStore with a hash depth of 8" do

	before(:each) do
	    @fs = ThingFish::FileStore.create( 'filesystem', :hashdepth => 8, :root => '.' )
		@io = StringIO.new( TEST_RESOURCE_CONTENT )
	end

	path = %W{ . 6 0 a c c 0 1 e #{TEST_UUID} } 
	it "uses a path with 8 subdirectories" do
		@fs.send( :hashed_path, TEST_UUID ).should ==
			Pathname.new( File.join(*path) )
	end
end

describe "A Filesystem FileStore with a hash depth that isn't a power of 2" do

	it "raises a config error" do
	    lambda {
			ThingFish::FileStore.create( 'filesystem', :hashdepth => 3 )
		}.should raise_error( ThingFish::ConfigError, /Hash depth must be 1,/i )
	end
end


describe "A FileSystem FileStore with a hash depth of greater than 8" do

	it "raises a config error" do
	    lambda {
			ThingFish::FileStore.create( 'filesystem', :hashdepth => 10 )
		}.should raise_error( ThingFish::ConfigError, /Max.*exceeded/i )
	end
end

describe "A Filesystem FileStore with a maxsize of 2k" do
	def make_tempdir
		dirname = "%s.%d.%0.4f" % [
			Pathname.new( __FILE__ ).basename('.rb'),
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		return Pathname.new( Dir.tmpdir ) + dirname
	end

	before(:all) do
		@tmpdir = make_tempdir()
	end

	
	before(:each) do
	    @fs = ThingFish::FileStore.create( 'filesystem',
		          :root => @tmpdir.to_s, :maxsize => 2_048 )
	end
	
	after(:each) do
		@tmpdir.rmtree
	end

	
	it "raises a FileStoreQuotaError when trying to store data > 3k" do
		lambda {
			@fs.store( TEST_UUID, '(.)(.)' * 1024 )
		}.should raise_error( ThingFish::FileStoreQuotaError )
	end

	it "raises a FileStoreQuotaError when trying to store a stream of data > 3k" do
		io = StringIO.new( '(.)(.)' * 1024 )
		lambda {
			@fs.store_io( TEST_UUID, io )
		}.should raise_error( ThingFish::FileStoreQuotaError )
	end

	it "raises a FileStoreQuotaError when trying to store two things whose sum is > 2k" do
		@fs.store( TEST_UUID, '!' * 1024 )
		lambda {
			@fs.store( TEST_UUID2, '!' * 1025 )
		}.should raise_error( ThingFish::FileStoreQuotaError )
	end
	
	it "raises a FileStoreQuotaError when trying to store two streams whose sum is > 2k" do
		@fs.store( TEST_UUID, '!' * 1024 )
		io = StringIO.new( '!' * 1025 )
		lambda {
			@fs.store_io( TEST_UUID2, io )
		}.should raise_error( ThingFish::FileStoreQuotaError )
	end
	
	it "is able to store a 1k chunk of data" do
		lambda {
			@fs.store( TEST_UUID, '!' * 1024 )
		}.should_not raise_error()
	end

	it "is able to store a 1k stream of data" do
		io = StringIO.new( '!' * 1024 )
		lambda {
			@fs.store_io( TEST_UUID, io )
		}.should_not raise_error()
	end
end

	


# TODO: test FileSystem 'quotas'

# vim: set nosta noet ts=4 sw=4:
