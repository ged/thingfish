#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'


describe "A Handler", :shared => true do
	include ThingFish::TestConstants
	include ThingFish::SpecHelpers


	after( :all ) do
		ThingFish.reset_logger
	end

end

