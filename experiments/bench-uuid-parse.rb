#!/usr/bin/ruby
#
# Benchmark UUIDTools' UUID parser vs. the one in the FilesystemFileStore plugin.
# 
# Time-stamp: <24-Aug-2003 16:11:13 deveiant>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	
	Pathname.glob( basedir + 'plugins' + '*' + 'lib' ) do |pluginlib|
		$LOAD_PATH.unshift( pluginlib.to_s )
	end

	require basedir + "utils.rb"
	include UtilityFunctions
}


require 'rubygems'
require 'benchmark'
require 'uuidtools'
require 'thingfish'
require 'thingfish/constants'

include UUIDTools

include ThingFish::Constants::Patterns
UUID_PATTERN = 	/^(#{HEX8})-(#{HEX4})-(#{HEX4})-(#{HEX2})(#{HEX2})-(#{HEX12})$/


### A more-efficient version of UUIDTools' UUID parser
def parse_uuid( uuid_string )
	unless match = UUID_PATTERN.match( uuid_string )
		raise ArgumentError, "Invalid UUID %p." % [uuid_string]
	end

	uuid_components = match.captures

	time_low = uuid_components[0].to_i( 16 )
	time_mid = uuid_components[1].to_i( 16 )
	time_hi_and_version = uuid_components[2].to_i( 16 )
	clock_seq_hi_and_reserved = uuid_components[3].to_i( 16 )
	clock_seq_low = uuid_components[4].to_i( 16 )

	nodes = []
	0.step( 11, 2 ) do |i|
		nodes << uuid_components[5][ i, 2 ].to_i( 16 )
	end

	return UUIDTools::UUID.new( time_low, time_mid, time_hi_and_version,
	                 clock_seq_hi_and_reserved, clock_seq_low, nodes )
end



uuid = '9c74650e-cc6d-11db-b5ad-cb306488e280'

n = 10_000
$stderr.puts "Running #{n} iterations"
Benchmark.bm( 10 ) do |bench|
	bench.report( "Null") do
		n.times {}
	end
	bench.report( "UUIDTools::UUID.parse" ) do
		n.times { u = UUIDTools::UUID.parse(uuid) }
	end
	bench.report( "parse_uuid" ) do
		n.times { u = parse_uuid(uuid) }
	end
end



#
# $ ruby -v experiments/bench-uuid-parse.rb 
# ruby 1.8.5 (2006-08-25) [powerpc-darwin8.7.0]
# Running 10000 iterations
#                 user     system      total        real
# Null        0.010000   0.000000   0.010000 (  0.002958)
# UUIDTools::UUID.parse  1.500000   0.030000   1.530000 (  1.733187)
# parse_uuid  0.780000   0.010000   0.790000 (  0.985533)
# 
