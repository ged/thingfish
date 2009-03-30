#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'

	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/metastore_behavior'

	require 'thingfish'
	require 'thingfish/metastore'
	require 'thingfish/metastore/rdf'

	$have_rdf = true
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end

	class ThingFish::RdfMetaStore
		DEFAULT_OPTIONS = {}
	end
	$have_rdf = false
end

describe ThingFish::RdfMetaStore do

	before(:all) do
		setup_logging( :fatal )
	end

	before( :each ) do
		pending "no Redland libraries installed" unless $have_rdf
		@store = ThingFish::MetaStore.create( 'rdf', nil, nil, :label => nil )
	end

	after( :all ) do
		reset_logging()
	end

	### Shared behavior specification
	it_should_behave_like "A MetaStore"
end

# vim: set nosta noet ts=4 sw=4:
