#!/usr/bin/env ruby

require_relative 'helpers'

require 'rspec'

require 'loggability/spechelpers'
require 'configurability/behavior'

require 'thingfish'


describe ThingFish do


	it "returns a version string if asked" do
		ThingFish.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		ThingFish.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
	end


end


# vim: set nosta noet ts=4 sw=4 ft=rspec:
