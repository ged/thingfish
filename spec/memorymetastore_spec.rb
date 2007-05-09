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
	require 'thingfish/metastore/memory'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe "An instance of MemoryMetaStore" do
	before(:each) do
		@store = ThingFish::MetaStore.create( 'memory' )
	end

	
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
end

# vim: set nosta noet ts=4 sw=4:
