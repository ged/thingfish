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
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

### Only run the specs for the RDF metastore if we can load the class
begin
	require 'thingfish/metastore/rdf'


	#####################################################################
	###	C O N T E X T S
	#####################################################################


	describe ThingFish::RdfMetaStore do
		include ThingFish::TestConstants,
			ThingFish::TestHelpers

		before(:each) do
			@tmpdir = make_tempdir()
		    @store = ThingFish::MetaStore.create( 'rdf', :root => @tmpdir.to_s )
		end
	
		after(:each) do
			@tmpdir.rmtree
		end

		# it_should_behave_like "A MetaStore"

	end

rescue LoadError => err
	describe "ThingFish::RdfMetaStore" do
		it "can't be loaded: #{err.message}"
	end
end

# vim: set nosta noet ts=4 sw=4:
