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

	it "can remove metadata for a UUID" do
		@store.save( TEST_UUID, TEST_METADATA )
		@store.remove( TEST_UUID )

		expect( @store.fetch(TEST_UUID) ).to be_nil
	end

	it "knows if it has data for a given OID" do
		@store.save( TEST_UUID, TEST_METADATA )
		expect( @store ).to include( TEST_UUID )
	end

	it "knows how many objects it contains" do
		expect( @store.size ).to eq( 0 )
		@store.save( TEST_UUID, TEST_METADATA )
		expect( @store.size ).to eq( 1 )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
