#!/usr/bin/env ruby

require_relative '../helpers'

require 'rspec'
require 'thingfish/processor'


describe Thingfish::Processor do

	before( :all ) do
		setup_logging()
	end


	it "has pluggability" do
		expect( described_class.plugin_type ).to eq( 'Processor' )
	end


	it "defines a (no-op) method for handling requests" do
		expect {
			described_class.new.process_request( nil )
		}.to_not raise_error
	end


	it "defines a (no-op) method for handling responses" do
		expect {
			described_class.new.process_response( nil )
		}.to_not raise_error
	end


end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
