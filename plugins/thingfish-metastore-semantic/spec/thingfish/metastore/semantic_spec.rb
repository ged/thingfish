#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

$_load_error = nil

require 'rbconfig'
require 'ipaddr'

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/advanced_metastore_behavior'

require 'thingfish'
require 'thingfish/metastore'

begin
	require 'thingfish/metastore/semantic'
rescue LoadError => err
	class ThingFish::SemanticMetaStore
		DEFAULT_OPTIONS = {}
	end

	$_load_error = err
end

describe ThingFish::SemanticMetaStore do

	before(:all) do
		setup_logging( :fatal )
	end

	before( :each ) do
		pending "couldn't load the semantic metastore: %s" % [ $_load_error ] if $_load_error
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent.parent.parent + 'resources'
		@store = ThingFish::MetaStore.create( 'semantic', nil, nil,
			:label => nil, :resource_dir => resdir )
	end

	after( :all ) do
		reset_logging()
	end


	it "registers IPAddr with Redleaf's node-conversion table" do
		addr = IPAddr.new( '192.168.16.87/32' )
		ipaddr_typeuri = ThingFish::SemanticMetaStore::IANA_NUMBERS[:ipaddr]

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
	it_should_behave_like "An advanced MetaStore"


	it "converts 'nil' metadata values to empty strings" do
		@store.set_property( TEST_UUID, 'dc:title', nil )
		@store.get_property( TEST_UUID, 'dc:title' ).should == ''
	end

	it "raises an exception when there is an unmapped qname" do
		expect {
			@store.set_property( TEST_UUID, 'meat:stinky', nil )
		}.to raise_error( ThingFish::MetaStoreError, /no vocab/ )
	end

end

# vim: set nosta noet ts=4 sw=4:
