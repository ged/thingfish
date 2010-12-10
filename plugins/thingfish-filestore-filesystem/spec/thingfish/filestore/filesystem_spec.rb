#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

require 'rspec'

require 'spec/lib/helpers'
require 'spec/lib/filestore_behavior'

require 'pathname'
require 'tmpdir'
require 'lockfile'
require 'thingfish/filestore/filesystem'


class Lockfile
	def trace( s=nil )
		s ||= yield
		ThingFish.logger.debug( s )
	end
end


#####################################################################
###	C O N T E X T S
#####################################################################

# protected -> public for testing ease
class ThingFish::FilesystemFileStore
	public :sizecache
end

describe ThingFish::FilesystemFileStore do
	include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::SpecHelpers


	before(:all) do
		setup_logging( :fatal )
		@tmpdir = make_tempdir()
		@spooldir = @tmpdir + 'foomp'
	end

	after( :all ) do
		reset_logging()
	end


	describe " with default settings" do
		before(:each) do
			lockopts = ThingFish::FilesystemFileStore::DEFAULT_LOCKING_OPTIONS
			lockopts[ :debug ] = true

		    @fs = ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir,
		 		:locking => lockopts )
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
			@io.stub!( :read ).and_return { raise Errno::ECONNRESET }

			lambda {
				@fs.store_io( TEST_UUID, @io )
			}.should raise_error( Errno::ECONNRESET )
		end

		it "cleans up after itself on upload errors" do
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
				uuid = UUIDTools::UUID.timestamp_create
				uuids << uuid
				@fs.store( uuid, TEST_RESOURCE_CONTENT )
				@fs.total_size.should == uuids.length * TEST_RESOURCE_CONTENT.length
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

		it "finds the top level hash directory" do
			resource = Pathname.new( "/tmp/thingfish/60/ac/c0/1e/#{TEST_UUID}" )
			@fs.sizecache( resource ).should == Pathname.new('/tmp/thingfish/60/.size')
		end
	end


	describe " with a hash depth of 2" do

		before(:each) do
		    @fs = ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir, :hashdepth => 2 )
			@io = StringIO.new( TEST_RESOURCE_CONTENT )
		end

		after(:each) do
			@tmpdir.rmtree
		end

		it "uses a path with 2 subdirectories" do
			@fs.send( :hashed_path, TEST_UUID ).should ==
				@tmpdir + File.join( '60ac', 'c01e', TEST_UUID )
		end

		it "finds the top level hash directory" do
			resource = Pathname.new( "/tmp/thingfish/60ac/c01e/#{TEST_UUID}" )
			@fs.sizecache( resource ).should == Pathname.new('/tmp/thingfish/60ac/.size')
		end

		### Behaviors
		it_should_behave_like "A FileStore"

	end


	describe " with a hash depth of 8" do

		before(:each) do
		    @fs = ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir, :hashdepth => 8 )
			@io = StringIO.new( TEST_RESOURCE_CONTENT )
		end

		after(:each) do
			@tmpdir.rmtree
		end

		it "uses a path with 8 subdirectories" do
			path = %W{ 6 0 a c c 0 1 e #{TEST_UUID} }
			expected_path = @tmpdir + File.join( *path )

			@fs.send( :hashed_path, TEST_UUID ).should == expected_path
		end

		it "finds the top level hash directory" do
			resource = Pathname.new( "/tmp/thingfish/6/0/a/c/c/0/1/e/#{TEST_UUID}" )
			@fs.sizecache( resource ).should == Pathname.new('/tmp/thingfish/6/.size')
		end

		### Behaviors
		it_should_behave_like "A FileStore"

	end

	describe " with a hash depth that isn't a power of 2" do
		it "raises a config error" do
		    lambda {
				ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir, :hashdepth => 3 )
			}.should raise_error( ThingFish::ConfigError, /Hash depth must be 1,/i )
		end
	end


	describe " with a hash depth of greater than 8" do
		it "raises a config error" do
		    lambda {
				ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir, :hashdepth => 10 )
			}.should raise_error( ThingFish::ConfigError, /Max.*exceeded/i )
		end
	end

	describe " with a maxsize of 2k" do

		before(:each) do
		    @fs = ThingFish::FileStore.create( 'filesystem', @tmpdir, @spooldir, :maxsize => 2_048 )
		end

		after(:each) do
			@tmpdir.rmtree
		end


		### Examples

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

		it "ensures any previously cached size files are destroyed" do
			scache = mock( "A cached size file" ).as_null_object
			Pathname.should_receive( :glob ).
				with( "#{@tmpdir}/*/.size" ).
				once.
				and_yield( scache )
			scache.should_receive( :unlink ).and_return( 1 )

		    @fs.on_startup
		end
	end


	describe " with size caching enabled" do

		before(:each) do
			@fs = ThingFish::FileStore.create( 'filesystem',
				@tmpdir, @spooldir, :cachesizes => true, :maxsize => 2_048 )
			@io = StringIO.new( TEST_RESOURCE_CONTENT )
		end

		after(:each) do
			@tmpdir.rmtree
		end


		it "creates cache files if needed at startup" do
			Pathname.should_receive( :glob ).with( "#{@tmpdir}/*/.size" )

			socketfile = mock( "Non plain-file datadir entry" )
			miscfile = mock( "Miscellaneous non-resource file" )
			resource1 = mock( "Resource pathname1" )
			resource2 = mock( "Resource pathname2" )

			@tmpdir.should_receive( :find ).
				and_yield( socketfile ).
				and_yield( miscfile ).
				and_yield( resource1 ).
				and_yield( resource2 )

			# First file isn't a plain file
			socketfile.should_receive( :file? ).and_return( false )
			socketfile.should_not_receive( :basename )
			socketfile.should_not_receive( :size )

			# second is something other than a resource file
			miscfile.should_receive( :file? ).and_return( true )
			miscfile.should_receive( :basename ).and_return( "something_thats_clearly_not_a_uuid.bz2" )
			miscfile.should_not_receive( :size )

			# Resource1
			resource1.should_receive( :file? ).and_return( true )
			resource1.should_receive( :basename ).and_return( TEST_UUID )
			resource1.should_receive( :size ).and_return( 100201 )

			resource1.stub!( :dirname ).and_return( resource1 )
			resource1.stub!( :parent ).and_return( resource1 ) # Emulate .parent
			sizefile1 = mock( "Resource1's size cache file" )
			resource1.should_receive( :+ ).with( '.size' ).and_return( sizefile1 )
			sizefile1.should_receive( :to_s ).and_return( "sizefile1" )
			Lockfile.should_receive( :new ).with( "sizefile1.lock", an_instance_of(Hash) ).and_yield
			sizefile1.should_receive( :exist? ).and_return( false )
			sizefile1.should_not_receive( :read )
			sizefile1_writer = mock( "Resource1's size cache file IO" )
			sizefile1.should_receive( :open ).with( 'w' ).and_yield( sizefile1_writer )
			sizefile1_writer.should_receive( :write ).with( 100201 )

			# Resource2
			resource2.should_receive( :file? ).and_return( true )
			resource2.should_receive( :basename ).and_return( TEST_UUID2 )
			resource2.should_receive( :size ).and_return( 166263 )

			resource2.stub!( :dirname ).and_return( resource2 )
			resource2.stub!( :parent ).and_return( resource2 ) # Emulate .parent
			sizefile2 = mock( "Resource2's size cache file" )
			resource2.should_receive( :+ ).with( '.size' ).and_return( sizefile2 )
			sizefile2.should_receive( :to_s ).and_return( "sizefile2" )
			Lockfile.should_receive( :new ).with( "sizefile2.lock", an_instance_of(Hash) ).and_yield
			sizefile2.should_receive( :exist? ).and_return( false )
			sizefile2.should_not_receive( :read )
			sizefile2_writer = mock( "Resource2's size cache file IO" )
			sizefile2.should_receive( :open ).with( 'w' ).and_yield( sizefile2_writer )
			sizefile2_writer.should_receive( :write ).with( 166263 )

			@fs.on_startup

			@fs.total_size.should == 100201 + 166263
		end

		it "uses cache files to calculate totals if available" do
			cachefile1 = mock( "Size cache file1" )
			cachefile2 = mock( "Size cache file2" )
			resource1 = mock( "Resource pathname1" )

			Pathname.should_receive( :glob ).with( "#{@tmpdir}/*/.size" ).
				and_yield( cachefile1 ).
				and_yield( cachefile2 )

			@tmpdir.should_not_receive( :find )

			cachefile1.should_receive( :read ).and_return( "102177" )
			cachefile2.should_receive( :read ).and_return( "6634" )

			@fs.on_startup
			@fs.total_size.should == 102177 + 6634
		end

		it "updates the cache file on resource deletion" do
			@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
			cachefile = @fs.sizecache( @tmpdir + '60/ac/c0/1e' + TEST_UUID )
			@fs.delete( TEST_UUID )
			cachefile.read.to_i.should == 0
		end

		it "updates the cache file on resource addition" do
			@fs.store( TEST_UUID, TEST_RESOURCE_CONTENT )
			cachefile = @fs.sizecache( @tmpdir + '60/ac/c0/1e' + TEST_UUID )
			cachefile.read.to_i.should == TEST_RESOURCE_CONTENT.length
		end
	end
end


# vim: set nosta noet ts=4 sw=4:
