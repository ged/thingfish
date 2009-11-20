#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/filter'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


describe "A Filter", :shared => true do
	include ThingFish::TestConstants
	include ThingFish::SpecHelpers


	it "knows what types it handles" do
		@filter.handled_types.should be_an_instance_of( Array )
		@filter.handled_types.each {|f| f.should be_an_instance_of(ThingFish::AcceptParam) }
	end

	it "provides information about itself through its introspection interface" do
		@filter.info.should be_an_instance_of( Hash )
		@filter.info.should have_key( 'version' )
		@filter.info['version'].should be_an_instance_of( Array )
		@filter.info.should have_key( 'accepts' )
		@filter.info['accepts'].should be_an_instance_of( Array )
		@filter.info.should have_key( 'generates' )
		@filter.info['generates'].should be_an_instance_of( Array )
		@filter.info.should have_key( 'supports' )
		@filter.info['supports'].should be_an_instance_of( Array )
		@filter.info.should have_key( 'rev' )
		@filter.info['rev'].to_s.should =~ /^[[:xdigit:]]+$/
	end


	it "knows what its plugin name is" do
		@filter.class.plugin_name.should be_an_instance_of( String )
	end

end

