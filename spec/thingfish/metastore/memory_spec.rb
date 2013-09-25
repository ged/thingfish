#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/metastore'


describe Thingfish::Metastore, "memory" do

	before( :all ) do
		setup_logging()
	end

	before( :each ) do
		@store = Thingfish::Metastore.create( :memory )
	end

	it "can save and fetch data" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID) ).to eq( TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID) ).to_not be( TEST_METADATA.first )
	end


	it "returns nil when fetching metadata for an object that doesn't exist" do
		expect( @store.fetch(TEST_UUID) ).to be_nil
	end


	it "doesn't care about the case of the UUID when saving and fetching data" do
		@store.save( TEST_UUID.downcase, TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID) ).to eq( TEST_METADATA.first )
	end


	it "can save a single metadata value for a given oid" do
		test_val = TEST_METADATA.first['useragent']
		@store.save( TEST_UUID, 'useragent', test_val )
		expect( @store.fetch(TEST_UUID, :useragent) ).to eq( TEST_METADATA.first[:useragent] )
	end


	it "can fetch a single metadata value for a given oid" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID, :format) ).to eq( TEST_METADATA.first[:format] )
		expect( @store.fetch(TEST_UUID, :extent) ).to eq( TEST_METADATA.first[:extent] )
	end


	it "can fetch a slice of data for a given oid" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID, :format, :extent) )
			.to eq( TEST_METADATA.first.values_at(:format, :extent) )
	end


	it "returns nil when fetching a slice of data for an object that doesn't exist" do
		expect( @store.fetch(TEST_UUID, :format) ).to be_nil
	end


	it "doesn't care about the case of the UUID when fetching data" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store.fetch(TEST_UUID.downcase, :format) ).to eq( TEST_METADATA.first[:format] )
	end


	it "can update data" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		@store.merge( TEST_UUID, format: 'image/jpeg' )

		expect( @store.fetch(TEST_UUID, :format) ).to eq( 'image/jpeg' )
	end


	it "doesn't care about the case of the UUID when updating data" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		@store.merge( TEST_UUID.downcase, format: 'image/jpeg' )

		expect( @store.fetch(TEST_UUID, :format) ).to eq( 'image/jpeg' )
	end


	it "can remove metadata for a UUID" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		@store.remove( TEST_UUID )

		expect( @store.fetch(TEST_UUID) ).to be_nil
	end


	it "can remove a single key/value pair from the metadata for a UUID" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		@store.remove( TEST_UUID, :useragent )

		expect( @store.fetch(TEST_UUID, :useragent) ).to be_nil
	end


	it "can truncate metadata not in a list of keys for a UUID" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		@store.remove_except( TEST_UUID, :format, :extent )

		metadata = @store.fetch( TEST_UUID )
		expect( metadata ).to have( 2 ).members
		expect( metadata.keys ).to include( 'format', 'extent' )
	end


	it "knows if it has data for a given OID" do
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store ).to include( TEST_UUID )
	end


	it "knows how many objects it contains" do
		expect( @store.size ).to eq( 0 )
		@store.save( TEST_UUID, TEST_METADATA.first )
		expect( @store.size ).to eq( 1 )
	end


	context "with some uploaded metadata" do

		before( :each ) do
			@uuids = []
			TEST_METADATA.each do |file|
				uuid = SecureRandom.uuid
				@uuids << uuid
				@store.save( uuid, file )
			end
		end


		it "can fetch an array of all of its keys" do
			expect( @store.keys ).to eq( @uuids )
		end

		it "can iterate over each of the store's keys" do
			uuids = []
			@store.each_key {|u| uuids << u }

			expect( uuids ).to eq( @uuids )
		end

		it "can provide an enumerator over each of the store's keys" do
			expect( @store.each_key.to_a ).to eq( @uuids )
		end

		it "can search for uuids" do
			expect( @store.search.to_a ).to eq( @store.keys )
		end

		it "can limit the number of results returned from a search" do
			expect( @store.search( limit: 2 ).to_a ).to eq( @store.keys[0,2] )
		end

	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
