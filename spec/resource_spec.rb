#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/constants'
	require 'thingfish'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


TEST_DATA = <<EOF
Something.
EOF

#####################################################################
###	E X A M P L E S
#####################################################################

describe ThingFish::Resource do
	include ThingFish::TestConstants

	it "can be created from an IO" do
		io = StringIO.new( TEST_DATA )
		ThingFish::Resource.new( io )
	end
end

# vim: set nosta noet ts=4 sw=4:
