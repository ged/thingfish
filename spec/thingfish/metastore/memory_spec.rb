#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/metastore/memory'
require 'thingfish/behavior/metastore'


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::MemoryMetaStore do

	TEST_MEMORY_METADATA = {
		ThingFish::TestConstants::TEST_UUID => {
			:title => 'Kangaroo Bombs the Title Company',
			:author => 'K. Roo',
		},
		ThingFish::TestConstants::TEST_UUID2 => {
			:title => 'Pinnochio was a Gigalo: The "Lie to Me Baby" Story',
			:author => 'J. K. Rowling',
		}
	}

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :metastore ) do
		ThingFish::MetaStore.create( 'memory' )
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like "a metastore"


	it "searches its internal hash for exact matches by comparing values" do
		TEST_MEMORY_METADATA.each do |uuid, properties|
			self.metastore.set_properties( uuid, properties )
		end
		self.metastore.find_exact_uuids( 'author', 'K. Roo' ).
			should == { TEST_UUID => TEST_MEMORY_METADATA[TEST_UUID] }
	end


	it "searches its internal hash for pattern matches by comparing values" do
		TEST_MEMORY_METADATA.each do |uuid, properties|
			self.metastore.set_properties( uuid, properties )
		end
		self.metastore.find_matching_uuids( 'title', '*giga*' ).
			should == { TEST_UUID2 => TEST_MEMORY_METADATA[TEST_UUID2] }
	end


end

# vim: set nosta noet ts=4 sw=4:
