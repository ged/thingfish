#!/usr/bin/env ruby

require 'rspec'

require 'thingfish'
require 'thingfish/filter'
require 'thingfish/testconstants'


share_examples_for "a filter" do
	include ThingFish::TestConstants

	it "knows what types it handles" do
		filter.handled_types.should be_an_instance_of( Array )
		filter.handled_types.each {|f| f.should be_an_instance_of(ThingFish::AcceptParam) }
	end

	it "provides information about itself through its introspection interface" do
		filter.info.should be_an_instance_of( Hash )
		filter.info.should have_key( 'version' )
		filter.info['version'].should be_an_instance_of( Array )
		filter.info.should have_key( 'accepts' )
		filter.info['accepts'].should be_an_instance_of( Array )
		filter.info.should have_key( 'generates' )
		filter.info['generates'].should be_an_instance_of( Array )
		filter.info.should have_key( 'supports' )
		filter.info['supports'].should be_an_instance_of( Array )
		filter.info.should have_key( 'rev' )
		filter.info['rev'].to_s.should =~ /^[[:xdigit:]]+$/
	end


	it "knows what its plugin name is" do
		described_class.plugin_name.should be_an_instance_of( String )
	end

end

