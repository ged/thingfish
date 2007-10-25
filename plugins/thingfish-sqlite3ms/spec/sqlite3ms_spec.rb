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
	require 'spec/lib/metastore_behavior'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish/metastore/sqlite3'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestHelpers
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe "A SQLite3 MetaStore" do
	
	before(:all) do
#		ThingFish.logger = Logger.new( $stderr )
#		ThingFish.logger.level = Logger::DEBUG

		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
		@tmpdir = make_tempdir()
	    @store = ThingFish::MetaStore.create( 'sqlite3',
			:root => @tmpdir.to_s,
			:resource_dir => resdir
		)
		@store.begin_transaction
	end

	after(:each) do
		@store.clear
	end

	after(:all) do
		@store.commit
		@tmpdir.rmtree
	end

	it_should_behave_like "A MetaStore"
	
	it "can load the SQL schema it uses from its resource directory" do
		@store.schema.should =~ /CREATE TABLE\s*'resources'/
	end

	it "knows what revision of the schema is installed" do
		@store.installed_schema_rev.should be_a_kind_of( Integer )
	end

	it "knows what rev of the schema is in its resources dir" do
		@store.schema_rev.should be_a_kind_of( Integer )
	end
	
	it "knows when its schema is out of date" do
		mock_db = mock( "db handle", :null_object => true )
		@store.metadata = mock_db
		
		rev = @store.schema_rev
		
		mock_db.should_receive( :user_version ).
			at_least(:once).
			and_return( rev - 5 )
		@store.db_needs_update?.should == true
	end
end

# vim: set nosta noet ts=4 sw=4:
