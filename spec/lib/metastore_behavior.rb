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
	require 'thingfish/metastore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


describe "A MetaStore", :shared => true do
	include ThingFish::TestConstants
	include ThingFish::TestHelpers

	it "can set and get a property belonging to a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can set a property belonging to a UUID object" do
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can get a property belonging to a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID_OBJ, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can test whether or not a property exists for a UUID" do
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_true
	end

	it "can test whether or not a property exists for a UUID object" do
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_true
	end

	it "can return the entire set of properties for a UUID" do
		@store.get_properties( TEST_UUID ).should be_empty
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end

	it "can get the entire set of properties for a UUID object" do
		@store.get_properties( TEST_UUID_OBJ ).should be_empty
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP2.to_sym )
	end

	it "can set the entire set of properties for a UUID object" do
		@store.get_properties( TEST_UUID ).should be_empty
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
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

	it "can remove a property for a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_property( TEST_UUID_OBJ, TEST_PROP )
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

	it "can remove all properties for a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_properties( TEST_UUID_OBJ )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end

	it "can fetch all keys for all properties in the store" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_all_property_keys.should have(2).members
		@store.get_all_property_keys.should include( TEST_PROP.to_sym )
		@store.get_all_property_keys.should include( TEST_PROP2.to_sym )
	end
	
	
	it "can fetch all values for a given key in the store" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID2, TEST_PROP, TEST_PROPVALUE2 )
		@store.set_property( TEST_UUID3, TEST_PROP, TEST_PROPVALUE2 )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_all_property_values( TEST_PROP ).should have(2).members
		@store.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE )
		@store.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE2 )
	end
	
	
	# Searching APIs
	
	it "can find UUID by single-property exact match" do
		@store.set_property( TEST_UUID, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = @store.find_by_exact_properties( 'title' => TEST_TITLE )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end

	it "can find UUIDs by multi-property exact match" do
		@store.set_property( TEST_UUID,  :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :title, TEST_TITLE )
		@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )
		@store.set_property( TEST_UUID2, :namespace, 'private' )

		found = @store.find_by_exact_properties(
		 	'title'    => TEST_TITLE,
			'namespace' => 'devlibrary'
		  )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end


	# Transaction API
	
	it "can execute a block in the context of a transaction" do
		ran_block = false
		@store.transaction do
			ran_block = true
		end
		
		ran_block.should be_true()
	end

end

