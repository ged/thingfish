#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/metastore'


describe Thingfish::Metastore, "memory" do

	TEST_METADATA = {
		format: 'image/png',
		extent: 14417
	}.freeze


	before( :all ) do
		setup_logging()
	end

	before( :each ) do
		@store = Thingfish::Metastore.create(:memory)
	end


	it "can save and fetch data" do
		@store.save( TEST_UUID, TEST_METADATA )
		expect( @store.fetch(TEST_UUID) ).to eq( TEST_METADATA )
		expect( @store.fetch(TEST_UUID) ).to_not be( TEST_METADATA )
	end


	it "doesn't care about the case of the UUID when saving and fetching data" do
		@store.save( TEST_UUID.downcase, TEST_METADATA )
		expect( @store.fetch(TEST_UUID) ).to eq( TEST_METADATA )
	end


	it "can fetch a slice of data for a given oid" do
		@store.save( TEST_UUID, TEST_METADATA )
		expect( @store.fetch(TEST_UUID, :format) ).to eq( [TEST_METADATA[:format]] )
		expect( @store.fetch(TEST_UUID, :extent) ).to eq( [TEST_METADATA[:extent]] )
	end


	it "doesn't care about the case of the UUID when fetching data" do
		@store.save( TEST_UUID, TEST_METADATA )
		expect( @store.fetch(TEST_UUID.downcase, :format) ).to eq( [TEST_METADATA[:format]] )
	end


	it "can update data" do
		@store.save( TEST_UUID, TEST_METADATA )
		@store.merge( TEST_UUID, format: 'image/jpeg' )

		expect( @store.fetch(TEST_UUID, :format) ).to eq( ['image/jpeg'] )
	end

	it "doesn't care about the case of the UUID when updating data" do
		@store.save( TEST_UUID, TEST_METADATA )
		@store.merge( TEST_UUID.downcase, format: 'image/jpeg' )

		expect( @store.fetch(TEST_UUID, :format) ).to eq( ['image/jpeg'] )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
