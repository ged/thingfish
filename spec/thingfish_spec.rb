#!/usr/bin/env ruby

require_relative 'helpers'

require 'rspec'
require 'thingfish'


RSpec.describe Thingfish do

	it "returns a version string if asked" do
		expect( described_class.version_string ).to match( /\w+ [\d.]+/ )
	end


	it "returns a version string with a build number if asked" do
		expect( described_class.version_string(true) ).
			to match(/\w+ [\d.]+ \(build [[:xdigit:]]+\)/)
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
