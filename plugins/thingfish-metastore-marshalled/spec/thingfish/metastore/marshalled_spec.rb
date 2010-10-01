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
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/metastore_behavior'

require 'pathname'
require 'tmpdir'

require 'thingfish/metastore/marshalled'


#####################################################################
###	C O N T E X T S
#####################################################################


describe ThingFish::MarshalledMetaStore do
	include ThingFish::TestConstants,
		ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end

	before(:each) do
		@tmpdir = make_tempdir()
		@spooldir = @tmpdir + 'spool'
	    @store = ThingFish::MetaStore.create( 'marshalled', @tmpdir, @spooldir )
	end

	after(:each) do
		@tmpdir.rmtree
	end

	after( :all ) do
		reset_logging()
	end


	it_should_behave_like "A MetaStore"
end

# vim: set nosta noet ts=4 sw=4:
