#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/metastore'


describe Thingfish::Metastore, "memory" do

	before( :all ) do
		setup_logging()
	end


	let( :store ) { Thingfish::Metastore.create(:memory) }
	let( :data  ) {{
		format: 'image/png',
		extent: 14417
	}}


	it "can save and fetch data" do
		store.save( TEST_UUID, data )
		expect( store.fetch(TEST_UUID) ).to eq( data )
		expect( store.fetch(TEST_UUID) ).to_not be( data )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
