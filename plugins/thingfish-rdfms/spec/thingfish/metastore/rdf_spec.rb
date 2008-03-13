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

describe ThingFish::RdfMetaStore do
	include ThingFish::SpecHelpers,
		ThingFish::Constants,
		ThingFish::TestConstants


	DEFAULTS = ThingFish::RdfMetaStore::DEFAULT_OPTIONS

	before(:all) do
		setup_logging( :debug )
	end

	before( :each ) do
		pending "More development"
		@triplestore = mock( "triplestore", :null_object => true )
	end

	after( :all ) do
		reset_logging()
	end


	it "ignores the 'new' key in the config options hash" do
		# (Alphabetically ordered)
		stringopts = "hash-type='memory',new='yes',write='yes'"
		Redland::TripleStore.should_receive( :new ).
			with( DEFAULTS[:store], DEFAULTS[:name], stringopts ).
			and_return( @triplestore )
		Redland::Model.stub!( :new ).and_return( :model )
		
		config = { :options => {:new => 'no'} }
		ThingFish::MetaStore.create( 'rdf', config )
	end

	it "ignores the 'write' key in the config options hash" do
		# (Alphabetically ordered)
		stringopts = "hash-type='memory',new='yes',write='yes'"
		Redland::TripleStore.should_receive( :new ).
			with( DEFAULTS[:store], DEFAULTS[:name], stringopts ).
			and_return( @triplestore )
		Redland::Model.stub!( :new ).and_return( :model )
		
		config = { :options => {:write => 'no'} }
		ThingFish::MetaStore.create( 'rdf', config )
	end


	describe " an instance" do

		Schemas = ThingFish::RdfMetaStore::Schemas


		STORE_OPTIONS = {
			:store => 'hashes',
			:hash_type => 'memory',
		  }

		before( :each ) do
		    @store = ThingFish::MetaStore.create( 'rdf', STORE_OPTIONS )
		end

		after( :each ) do
			# @store.
		end

		### Shared behavior specification
		it_should_behave_like "A MetaStore"

	
		### Schema stuff
	
		it "loads RDF vocabularies specified in the config"
		it "maps incoming pairs onto user-specified vocabularies first"
		it "maps incoming pairs onto standard vocabularies if there is no matching predicate in " +
		   "the user-specified vocabularies"
		it "maps incoming pairs onto the thingfish vocabulary if there is no matching predicate in " +
		   "either the user-specified vocabularies or the standard vocabularies"

	end
end

# vim: set nosta noet ts=4 sw=4:
