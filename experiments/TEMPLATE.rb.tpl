#!/usr/bin/env ruby
#
# #{vars[:description]}
# 
# Time-stamp: <24-Aug-2003 16:11:13 deveiant>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )

	require basedir + "utils.rb"
	include UtilityFunctions
}

try( "#{tm[:filepath]}" ) {
	$0
}




