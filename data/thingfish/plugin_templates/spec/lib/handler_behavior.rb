#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'


describe "A Handler", :shared => true do
	include ThingFish::TestConstants


	after( :all ) do
		reset_logging()
	end

end

