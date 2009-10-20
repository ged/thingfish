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

$rdfmetastore_load_error = nil

begin
	require 'rbconfig'
	require 'ipaddr'

	require 'spec'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/metastore_behavior'

	require 'thingfish'
	require 'thingfish/metastore'
	require 'thingfish/metastore/rdf'
rescue LoadError => err
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end

	class ThingFish::RdfMetaStore
		DEFAULT_OPTIONS = {}
	end

	$rdfmetastore_load_error = err
end

describe ThingFish::RdfMetaStore do

	before(:all) do
		setup_logging( :fatal )
	end

	before( :each ) do
		pending "couldn't load the RDF metastore: %s" % [ $rdfmetastore_load_error ] if
			$rdfmetastore_load_error
		@store = ThingFish::MetaStore.create( 'rdf', nil, nil, :label => nil )
	end

	after( :all ) do
		reset_logging()
	end


	it "registers IPAddr with Redleaf's node-conversion table" do
		addr = IPAddr.new( '192.168.16.87/32' )
		ipaddr_typeuri = ThingFish::RdfMetaStore::IANA_NUMBERS[:ipaddr]

		Redleaf::NodeUtils.make_object_typed_literal( addr ).should ==
			[ "ipv4:192.168.16.87/255.255.255.255", ipaddr_typeuri ]
	end

	it "converts Rational numbers to decimal approximations" do
		num = Rational( 3,8 )
		lit_tuple = Redleaf::NodeUtils.make_object_typed_literal( num )

		lit_tuple[0].should be_close( 3.0/8.0, 0.001 )
		lit_tuple[1].should == Redleaf::Constants::CommonNamespaces::XSD[:decimal]
	end


	### Shared behavior specification
	it_should_behave_like "A MetaStore"


	it "converts 'nil' metadata values to empty strings" do
		uuid = UUIDTools::UUID.timestamp_create
		@store.set_property( uuid, :exif_comment, nil )
		@store.get_property( uuid, :exif_comment ).should == ''
	end

end

# vim: set nosta noet ts=4 sw=4:
