#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants


class TestFilter < ThingFish::Filter
end



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::Filter do
	it "registers subclasses as plugins" do
		ThingFish::Filter.get_subclass( 'test' ).should == TestFilter
	end
	
	
	it ""
	
end




# vim: set nosta noet ts=4 sw=4:
