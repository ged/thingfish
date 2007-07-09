#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'logger'
	require 'thingfish'
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

describe "The ThingFish module" do
	before(:each) do
		ThingFish.reset_logger
	end

	after(:each) do
		ThingFish.reset_logger
	end
	
	
	it "has a default logger instance" do
		ThingFish.logger.should be_a_kind_of( Logger )
	end
	
	it "should know if its default logger is replaced" do
		ThingFish.should be_using_default_logger
		ThingFish.logger = Logger.new( $stderr )
		ThingFish.should_not be_using_default_logger
	end

	it "returns a version string if asked" do
		ThingFish.version_string.should =~ /\w+ [\d.]+/
	end

	it "returns a version string with a build number if asked" do
		ThingFish.version_string(true).should =~ /\w+ [\d.]+ \(build \d+\)/
	end
end

# vim: set nosta noet ts=4 sw=4:
