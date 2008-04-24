#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/metastore/memory'
	require 'spec/lib/metastore_behavior'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

#####################################################################
###	C O N T E X T S
#####################################################################

describe "An instance of MemoryMetaStore" do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end
	
	before(:each) do
		@store = ThingFish::MetaStore.create( 'memory' )
	end

	after(:all) do
		reset_logging()
	end
	
	
	it_should_behave_like "A MetaStore"	

end

# vim: set nosta noet ts=4 sw=4:
