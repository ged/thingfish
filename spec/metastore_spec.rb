#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/metastore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants;

class TestMetaStore < ThingFish::MetaStore
end

#####################################################################
###	C O N T E X T S
#####################################################################

describe TestMetaStore, " (MetaStore derivative class)" do
	
	before(:each) do
		@metastore = ThingFish::MetaStore.create( 'test' )
	end
	
	
	it "raises NotImplementedError for #has_property?" do
		lambda {
			@metastore.has_property?( TEST_UUID, TEST_PROP )
		}.should raise_error( NotImplementedError, /#has_property?/ )
	end

	it "raises NotImplementedError for #set_property" do
		lambda {
			@metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		}.should raise_error( NotImplementedError, /#set_property/ )
	end

	it "raises NotImplementedError for #get_property" do
		lambda {
			@metastore.get_property( TEST_UUID, TEST_PROP )
		}.should raise_error( NotImplementedError, /#get_property/ )
	end


	it "raises NotImplementedError for #get_properties" do
		lambda {
			@metastore.get_properties( TEST_UUID )
		}.should raise_error( NotImplementedError, /#get_properties/ )
	end

	it "raises NotImplementedError for #delete_property" do
		lambda {
			@metastore.delete_property( TEST_UUID, TEST_PROP )
		}.should raise_error( NotImplementedError, /#delete_property/ )
	end

	it "raises NotImplementedError for #delete_properties" do
		lambda {
			@metastore.delete_properties( TEST_UUID, TEST_PROP )
		}.should raise_error( NotImplementedError, /#delete_properties/ )
	end

	it "raises NotImplementedError for #get_all_property_keys" do
		lambda {
			@metastore.get_all_property_keys( TEST_UUID, TEST_PROP )
		}.should raise_error( NotImplementedError, /#get_all_property_keys/ )
	end
	
	it "returns a ResourceProxy to use when interacting with a resource's metadata set" do
	    @metastore[ TEST_UUID ].
			should be_a_kind_of( ThingFish::MetaStore::ResourceProxy )
	end
	
	it "returns the same ResourceProxy for a string UUID as for the same UUID object" do
		uuid_obj = UUID.parse( TEST_UUID )
		@metastore[ TEST_UUID ].should == @metastore[ uuid_obj ]
	end

	it "throws an exception if the proxy class isn't set in the index operator method [bug #2]" do
		@metastore.instance_variable_set( :@proxy_class, nil )
		lambda {
			@metastore[ TEST_UUID ]
		}.should raise_error( ThingFish::PluginError, /did not call.+initializer/ )
	end

	it "can extract a default set of metadata for new uploaded resources" do
		params = {
			'CONTENT_TYPE'    => 'foo/bar',
			'CONTENT_LENGTH'  => 162663,
			'HTTP_USER_AGENT' => 'PyFish/1.2',
			'REMOTE_ADDR'     => '198.145.180.83',
		}
		
		mock_proxy = mock( "mock_name", :null_object => true )
		proxy_class = stub( "metadata proxy", :new => mock_proxy )
		request = mock( "mock_name", :null_object => true )
		
		@metastore.proxy_class = proxy_class
		
		request.should_receive( :params ).at_least( :once ).and_return( params )

		mock_proxy.should_receive( :format= ).with( params['CONTENT_TYPE'] )
		mock_proxy.should_receive( :extent= ).with( params['CONTENT_LENGTH'] )
		mock_proxy.should_receive( :useragent= ).with( params['HTTP_USER_AGENT'] )
		mock_proxy.should_receive( :uploadaddress= ).with( params['REMOTE_ADDR'] )

		mock_proxy.should_receive( :created ).and_return( false )
		mock_proxy.should_receive( :created= ).with( duck_type( :strftime ) )
		mock_proxy.should_receive( :modified= ).with( duck_type(:strftime) )

		@metastore.extract_default_metadata( TEST_UUID, request )
	end
end


describe ThingFish::MetaStore::ResourceProxy do
	before(:each) do
		@store = mock( "metadata store" )
		@proxy = ThingFish::MetaStore::ResourceProxy.new( TEST_UUID, @store )
	end


	it "delegates to the store for a proxied predicate method" do
	    @store.should_receive( :has_property? ).with( TEST_UUID, 'format' )
		@proxy.has_format?
	end

	it "delegates to the store for an attribute writer" do
	    @store.should_receive( :set_property ).with( TEST_UUID, 'format', TEST_PROPVALUE )
		@proxy.format = TEST_PROPVALUE
	end

	it "delegates to the store for an attribute reader" do
	    @store.should_receive( :get_property ).with( TEST_UUID, 'format' )
		@proxy.format
	end

	it "delegates to the store's #get_properties for iteration" do
		@store.should_receive( :get_properties ).with( TEST_UUID ).
			and_return({ TEST_PROP => TEST_PROPVALUE })
		@proxy.each do |pair|
			pair.should == [TEST_PROP, TEST_PROPVALUE]
		end
	end

	it "considers instances with the same UUID as equivalent" do
		proxy2 = ThingFish::MetaStore::ResourceProxy.new( TEST_UUID, @store )
		proxy2.should == @proxy
	end

end


describe ThingFish::MetaStore do

	it "registers subclasses as plugins" do
		ThingFish::MetaStore.get_subclass( 'test' ).should == TestMetaStore
	end
	
end


# vim: set nosta noet ts=4 sw=4:

