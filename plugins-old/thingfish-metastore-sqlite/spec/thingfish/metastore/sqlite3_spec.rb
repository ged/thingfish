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

require 'spec'
require 'spec/lib/metastore_behavior'
require 'spec/lib/helpers'

require 'pathname'
require 'tmpdir'

require 'thingfish/metastore/sqlite3'


#####################################################################
###	C O N T E X T S
#####################################################################

describe "A SQLite3 MetaStore" do
	include ThingFish::SpecHelpers,
		ThingFish::TestConstants

	before( :all ) do
		setup_logging( :fatal )

		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent.parent.parent + 'resources'
		@tmpdir = make_tempdir()
	    @store = ThingFish::MetaStore.create( 'sqlite3', @tmpdir, nil, :resource_dir => resdir )
		@store.begin_transaction
	end

	after(:each) do
		@store.clear
	end

	after(:all) do
		@store.commit
		@tmpdir.rmtree

		reset_logging()
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
		mock_db = mock( "db handle" ).as_null_object
		@store.metadata = mock_db

		rev = @store.schema_rev

		mock_db.should_receive( :user_version ).
			at_least(:once).
			and_return( rev - 5 )
		@store.db_needs_update?.should == true
	end
end

# vim: set nosta noet ts=4 sw=4:
