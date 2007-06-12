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
require 'spec/constants'
require 'thingfish/constants'

require 'thingfish/metastore/sqlite3'

include ThingFish::Constants
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe "A SQLite3 MetaStore" do

	def make_tempdir
		dirname = "%s.%d.%0.4f" % [
			Pathname.new( __FILE__ ).basename('.rb'),
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		return Pathname.new( Dir.tmpdir ) + dirname
	end

	before(:all) do
		# ThingFish.logger = Logger.new( $deferr )
		# ThingFish.logger.level = Logger::DEBUG

		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
		@tmpdir = make_tempdir()
		# $deferr.puts "Creating sqlite3 store: %p" % @tmpdir.to_s
	    @store = ThingFish::MetaStore.create( 'sqlite3',
			:root => @tmpdir.to_s,
			:resource_dir => resdir
		  )
	end

	after(:each) do
		@store.clear
	end

	after(:all) do
		@tmpdir.rmtree
	end


	### Specs
	it "can set and get a property belonging to a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can test whether or not a property exists for a UUID" do
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_true
	end

	it "can return the entire set of properties for a UUID" do
		@store.get_properties( TEST_UUID ).should be_empty
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end
	
	it "can remove a property for a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_property( TEST_UUID, TEST_PROP )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_true
	end

	it "can remove all properties for a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_properties( TEST_UUID )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end
	
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