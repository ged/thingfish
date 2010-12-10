#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'thingfish'
require 'thingfish/#{vars[:specified_class].downcase}'


#####################################################################
###	E X A M P L E S
#####################################################################

describe #{vars[:class_under_test]} do

end

# vim: set nosta noet ts=4 sw=4:
