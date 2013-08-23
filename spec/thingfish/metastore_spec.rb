#!/usr/bin/env ruby

require_relative '../helpers'

require 'rspec'
require 'thingfish/metastore'

class TestingMetastore < Thingfish::Metastore
end


describe Thingfish::Metastore do

	before( :all ) do
		setup_logging()
	end


	it "is abstract" do
		expect { described_class.new }.to raise_error( NoMethodError, /private/i )
	end


	it "acts as a factory for its concrete derivatives" do
		expect( described_class.create('testing') ).to be_a( TestingMetastore )
	end


	describe "an instance of a concrete derivative" do

		let( :store ) { described_class.create('testing') }

		it "raises an error if it doesn't implement #fetch" do
			expect { store.fetch(TEST_UUID) }.to raise_error( NotImplementedError, /fetch/ )
		end

		it "raises an error if it doesn't implement #save" do
			expect {
				store.save( TEST_UUID, {name: 'foo'} )
			}.to raise_error( NotImplementedError, /save/ )
		end

		it "raises an error if it doesn't implement #merge" do
			expect {
				store.merge( TEST_UUID, {name: 'foo'} )
			}.to raise_error( NotImplementedError, /merge/ )
		end

		it "raises an error if it doesn't implement #include?" do
			expect { store.include?(TEST_UUID) }.to raise_error( NotImplementedError, /include\?/ )
		end

		it "raises an error if it doesn't implement #remove" do
			expect { store.remove(TEST_UUID) }.to raise_error( NotImplementedError, /remove/ )
		end

		it "raises an error if it doesn't implement #size" do
			expect { store.size }.to raise_error( NotImplementedError, /size/ )
		end

	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
