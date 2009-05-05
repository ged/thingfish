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

	require 'spec'
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


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::RdfMetaStore do
	include ThingFish::SpecHelpers,
		ThingFish::Constants,
		ThingFish::TestConstants


	DEFAULTS = ThingFish::RdfMetaStore::DEFAULT_OPTIONS

	before(:all) do
		setup_logging( :fatal )
	end

	before( :each ) do
		pending "no Redland libraries installed" unless $have_rdf
		@triplestore = mock( "triplestore", :null_object => true )
	end

	after( :all ) do
		reset_logging()
	end


	it "ignores the 'new' key in the config options hash" do
		# (Alphabetically ordered)
		stringopts = "hash-type='memory',new='yes',password='',write='yes'"
		Redland::TripleStore.should_receive( :new ).
			with( DEFAULTS[:store], DEFAULTS[:name], stringopts ).
			and_return( @triplestore )
		Redland::Model.stub!( :new ).and_return( :model )

		config = { :options => {:new => 'no'} }
		ThingFish::MetaStore.create( 'rdf', nil, nil, config )
	end


	it "ignores the 'write' key in the config options hash" do
		# (Alphabetically ordered)
		stringopts = "hash-type='memory',new='yes',password='',write='yes'"
		Redland::TripleStore.should_receive( :new ).
			with( DEFAULTS[:store], DEFAULTS[:name], stringopts ).
			and_return( @triplestore )
		Redland::Model.stub!( :new ).and_return( :model )

		config = { :options => {:write => 'no'} }
		ThingFish::MetaStore.create( 'rdf', nil, nil, config )
	end


	it "doesn't clobber a password if specified in the config options hash" do
		# (Alphabetically ordered)
		stringopts = "hash-type='memory',new='yes',password='n\\'robot',write='yes'"
		Redland::TripleStore.should_receive( :new ).
			with( DEFAULTS[:store], DEFAULTS[:name], stringopts ).
			and_return( @triplestore )
		Redland::Model.stub!( :new ).and_return( :model )

		config = { :options => {:password => "n'robot"} }
		ThingFish::MetaStore.create( 'rdf', nil, nil, config )
	end


	describe " with default configuration values " do

		STORE_OPTIONS = {
			:store => 'hashes',
			:hash_type => 'memory',
		  }

		before( :each ) do
			pending "no Redland libraries installed" unless $have_rdf
		    @store = ThingFish::MetaStore.create( 'rdf', nil, nil, STORE_OPTIONS )
		end

		after( :each ) do
			# @store.clear
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
