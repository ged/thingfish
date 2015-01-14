# -*- ruby -*-
#encoding: utf-8

require 'rspec'


RSpec.shared_examples "a Thingfish metastore" do

	let( :metastore ) do
		Thingfish::Metastore.create( described_class )
	end


	it "can save and fetch data" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore.fetch(TEST_UUID) ).to eq( TEST_METADATA.first )
		expect( metastore.fetch(TEST_UUID) ).to_not be( TEST_METADATA.first )
	end


	it "returns nil when fetching metadata for an object that doesn't exist" do
		expect( metastore.fetch(TEST_UUID) ).to be_nil
	end


	it "doesn't care about the case of the UUID when saving and fetching data" do
		metastore.save( TEST_UUID.downcase, TEST_METADATA.first )
		expect( metastore.fetch(TEST_UUID) ).to eq( TEST_METADATA.first )
	end


	it "can fetch a single metadata value for a given oid" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore.fetch_value(TEST_UUID, :format) ).to eq( TEST_METADATA.first['format'] )
		expect( metastore.fetch_value(TEST_UUID, :extent) ).to eq( TEST_METADATA.first['extent'] )
	end


	it "can fetch a slice of data for a given oid" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore.fetch(TEST_UUID, :format, :extent) ).to eq({
			'format' => TEST_METADATA.first['format'],
			'extent' => TEST_METADATA.first['extent'],
		})
	end


	it "returns nil when fetching a slice of data for an object that doesn't exist" do
		expect( metastore.fetch_value(TEST_UUID, :format) ).to be_nil
	end


	it "doesn't care about the case of the UUID when fetching data" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore.fetch_value(TEST_UUID.downcase, :format) ).to eq( TEST_METADATA.first['format'] )
	end


	it "can update data" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		metastore.merge( TEST_UUID, format: 'image/jpeg' )

		expect( metastore.fetch_value(TEST_UUID, :format) ).to eq( 'image/jpeg' )
	end


	it "doesn't care about the case of the UUID when updating data" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		metastore.merge( TEST_UUID.downcase, format: 'image/jpeg' )

		expect( metastore.fetch_value(TEST_UUID, :format) ).to eq( 'image/jpeg' )
	end


	it "can remove metadata for a UUID" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		metastore.remove( TEST_UUID )

		expect( metastore.fetch(TEST_UUID) ).to be_nil
	end


	it "can remove a single key/value pair from the metadata for a UUID" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		metastore.remove( TEST_UUID, :useragent )

		expect( metastore.fetch_value(TEST_UUID, :useragent) ).to be_nil
	end


	it "can truncate metadata not in a list of keys for a UUID" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		metastore.remove_except( TEST_UUID, :format, :extent )

		metadata = metastore.fetch( TEST_UUID )
		expect( metadata.size ).to be( 2 )
		expect( metadata.keys ).to include( 'format', 'extent' )
	end


	it "knows if it has data for a given OID" do
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore ).to include( TEST_UUID )
	end


	it "knows how many objects it contains" do
		expect( metastore.size ).to eq( 0 )
		metastore.save( TEST_UUID, TEST_METADATA.first )
		expect( metastore.size ).to eq( 1 )
	end


	it "knows how to fetch UUIDs for related resources" do
		rel_uuid1 = SecureRandom.uuid
		rel_uuid2 = SecureRandom.uuid
		unrel_uuid = SecureRandom.uuid

		metastore.save( rel_uuid1, TEST_METADATA[0].merge('relation' => TEST_UUID.downcase) )
		metastore.save( rel_uuid2, TEST_METADATA[1].merge('relation' => TEST_UUID.downcase) )
		metastore.save( unrel_uuid, TEST_METADATA[2] )

		uuids = metastore.fetch_related_uuids( TEST_UUID )

		expect( uuids ).to include( rel_uuid1, rel_uuid2 )
		expect( uuids ).to_not include( unrel_uuid )
	end


	context "with some uploaded metadata" do

		before( :each ) do
			@uuids = []
			TEST_METADATA.each do |file|
				uuid = SecureRandom.uuid
				@uuids << uuid
				metastore.save( uuid, file )
			end
		end


		it "can fetch an array of all of its keys" do
			expect( metastore.keys ).to eq( @uuids )
		end

		it "can iterate over each of the store's keys" do
			uuids = []
			metastore.each_key {|u| uuids << u }

			expect( uuids ).to eq( @uuids )
		end

		it "can provide an enumerator over each of the store's keys" do
			expect( metastore.each_key.to_a ).to eq( @uuids )
		end

		it "can search for uuids" do
			expect( metastore.search.to_a ).to eq( metastore.keys )
		end

		it "can apply criteria to searches" do
			results = metastore.search( :criteria => {'format' => 'audio/mp3'} )
			expect( results.size ).to be( 2 )
			results.each do |uuid|
				expect( metastore.fetch_value(uuid, 'format') ).to eq( 'audio/mp3' )
			end
		end

		it "can limit the number of results returned from a search" do
			expect( metastore.search( limit: 2 ).to_a ).to eq( metastore.keys[0,2] )
		end

	end


end
