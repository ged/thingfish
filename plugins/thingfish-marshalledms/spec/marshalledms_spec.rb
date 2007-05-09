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

require 'thingfish/metastore/marshalled'



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants


MMS_TEST_KEY    = '12ad84d8-bb95-11db-a22e-0017f2004c5e'
MMS_TEST_PROP   = 'pie_flavor'
MMS_TEST_VALUE  = 'punkin'
MMS_TEST_PROP2  = 'beverage'
MMS_TEST_VALUE2 = 'beef-a-mato'


describe "A Marshalled MetaStore" do

	def make_tempdir
		dirname = "%s.%d.%0.4f" % [
			Pathname.new( __FILE__ ).basename('.rb'),
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		return Pathname.new( Dir.tmpdir ) + dirname
	end


	before(:each) do
		@tmpdir = make_tempdir()
	    @store = ThingFish::MetaStore.create( 'marshalled', :root => @tmpdir.to_s )
	end
	
	after(:each) do
		@tmpdir.rmtree
	end

	
	### Specs
	it "can set and get a property belonging to a UUID" do
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP, MMS_TEST_VALUE )
		@store.get_property( MMS_TEST_KEY, MMS_TEST_PROP ).should == MMS_TEST_VALUE
	end

	it "can test whether or not a property exists for a UUID" do
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP ).should be_false
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP, MMS_TEST_VALUE )
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP ).should be_true
	end

	it "can return the entire set of properties for a UUID" do
		@store.get_properties( MMS_TEST_KEY ).should be_empty
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP, MMS_TEST_VALUE )
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP2, MMS_TEST_VALUE2 )
		@store.get_properties( MMS_TEST_KEY ).should have_key( MMS_TEST_PROP.to_sym )
		@store.get_properties( MMS_TEST_KEY ).should have_key( MMS_TEST_PROP2.to_sym )
	end
	
	it "can remove a property for a UUID" do
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP, MMS_TEST_VALUE )
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP2, MMS_TEST_VALUE2 )
		@store.delete_property( MMS_TEST_KEY, MMS_TEST_PROP )
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP ).should be_false
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP2 ).should be_true
	end

	it "can remove all properties for a UUID" do
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP, MMS_TEST_VALUE )
		@store.set_property( MMS_TEST_KEY, MMS_TEST_PROP2, MMS_TEST_VALUE2 )
		@store.delete_properties( MMS_TEST_KEY )
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP ).should be_false
		@store.has_property?( MMS_TEST_KEY, MMS_TEST_PROP2 ).should be_false
	end
end

# vim: set nosta noet ts=4 sw=4:
