#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/datastore'


describe Thingfish::Datastore, "memory" do

	before( :all ) do
		setup_logging()
	end

	before( :each ) do
		@png_io = StringIO.new( TEST_PNG_DATA.dup )
		@text_io = StringIO.new( TEST_TEXT_DATA.dup )
	end

	before( :each ) do
		@store = Thingfish::Datastore.create(:memory)
	end


	it "can save data" do
		expect( @store.save(@png_io) ).to be_a_uuid()
	end

	it "restores the position of the IO after saving" do
		@png_io.pos = 11
		@store.save( @png_io )
		expect( @png_io.pos ).to eq( 11 )
	end

	it "can replace existing data" do
		new_uuid = @store.save( @text_io )
		@store.replace( new_uuid, @png_io )

		rval = @store.fetch( new_uuid )
		expect( rval ).to respond_to( :read )
		expect( rval.read ).to eq( TEST_PNG_DATA )
	end

	it "doesn't care about the case of the uuid when replacing" do
		new_uuid = @store.save( @text_io )
		@store.replace( new_uuid.upcase, @png_io )

		rval = @store.fetch( new_uuid )
		expect( rval ).to respond_to( :read )
		expect( rval.read ).to eq( TEST_PNG_DATA )
	end

	it "can fetch saved data" do
		oid = @store.save( @text_io )
		rval = @store.fetch( oid )

		expect( rval ).to respond_to( :read )
		expect( rval.external_encoding ).to eq( Encoding::ASCII_8BIT )
		expect( rval.read ).to eq( TEST_TEXT_DATA )
	end

	it "doesn't care about the case of the uuid when fetching" do
		oid = @store.save( @text_io )
		rval = @store.fetch( oid.upcase )

		expect( rval ).to respond_to( :read )
		expect( rval.read ).to eq( TEST_TEXT_DATA )
	end

	it "can remove data" do
		oid = @store.save( @text_io )
		@store.remove( oid )

		expect( @store.fetch(oid) ).to be_nil
	end

	it "knows if it has data for a given OID" do
		oid = @store.save( @text_io )
		expect( @store ).to include( oid )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
