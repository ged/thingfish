#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

begin
	require 'pathname'
	require 'tmpdir'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/metastore_behavior'
	require 'thingfish/metastore/marshalled'
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


describe ThingFish::MarshalledMetaStore do
	include ThingFish::TestConstants
	include ThingFish::SpecHelpers

	before(:each) do
		@tmpdir = make_tempdir()
	    @store = ThingFish::MetaStore.create( 'marshalled', :root => @tmpdir.to_s )
	end
	
	after(:each) do
		@tmpdir.rmtree
	end

	it_should_behave_like "A MetaStore"
end

# vim: set nosta noet ts=4 sw=4:
