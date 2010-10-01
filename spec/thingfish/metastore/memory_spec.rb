#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/helpers'
require 'spec/lib/metastore_behavior'

require 'thingfish'
require 'thingfish/metastore/memory'


#####################################################################
###	C O N T E X T S
#####################################################################

describe "An instance of MemoryMetaStore" do
	include ThingFish::SpecHelpers
	include ThingFish::TestConstants

	TEST_MEMORY_METADATA = {
		TEST_UUID => {
			:title => 'Kangaroo Bombs the Title Company',
			:author => 'K. Roo',
		},
		TEST_UUID2 => {
			:title => 'Pinnochio was a Gigalo: The "Lie to Me Baby" Story',
			:author => 'J. K. Rowling',
		}
	}

	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
		@store = ThingFish::MetaStore.create( 'memory' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like "A MetaStore"


	it "searches its internal hash for exact matches by comparing values" do
		TEST_MEMORY_METADATA.each do |uuid, properties|
			@store.set_properties( uuid, properties )
		end
		@store.find_exact_uuids( 'author', 'K. Roo' ).
			should == { TEST_UUID => TEST_MEMORY_METADATA[TEST_UUID] }
	end


	it "searches its internal hash for pattern matches by comparing values" do
		TEST_MEMORY_METADATA.each do |uuid, properties|
			@store.set_properties( uuid, properties )
		end
		@store.find_matching_uuids( 'title', '*giga*' ).
			should == { TEST_UUID2 => TEST_MEMORY_METADATA[TEST_UUID2] }
	end


end

# vim: set nosta noet ts=4 sw=4:
