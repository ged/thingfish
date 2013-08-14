#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/datastore'


describe Thingfish::Datastore, "memory" do

	before( :all ) do
		setup_logging()
	end


	let( :store ) { Thingfish::Datastore.create(:memory) }
	let( :data  ) { StringIO.new(TEST_PNG_DATA) }


	it "can save data" do
		expect( store.save(data) ).to be_a_uuid()
	end

	it "restores the position of the IO after saving" do
		begin
			data.pos = 11
			store.save( data )
			expect( data.pos ).to eq( 11 )
		ensure
			data.rewind
		end
	end

	it "can fetch saved data" do
		oid = store.save( data )
		expect( store.fetch(oid).read ).to eq( TEST_PNG_DATA )
	end


end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
