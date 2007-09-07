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
	include ThingFish::TestHelpers


	it "knows what types it handles" do
		@filter.handled_types.should be_an_instance_of( Array )
		@filter.handled_types.each {|f| f.should be_an_instance_of(ThingFish::AcceptParam) }
	end

	
end

