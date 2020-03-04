#!/usr/bin/env ruby

require_relative '../helpers'

require 'rspec'
require 'thingfish/datastore'

class TestingDatastore < Thingfish::Datastore
end


RSpec.describe Thingfish::Datastore do

	it "is abstract" do
		expect { described_class.new }.to raise_error( NoMethodError, /private/i )
	end


	it "acts as a factory for its concrete derivatives" do
		expect( described_class.create('testing') ).to be_a( TestingDatastore )
	end


	describe "an instance of a concrete derivative" do

		let( :store ) { described_class.create('testing') }

		it "raises an error if it doesn't implement #save" do
			expect { store.save(TEST_PNG_DATA) }.to raise_error( NotImplementedError, /save/ )
		end

		it "raises an error if it doesn't implement #replace" do
			expect { store.replace(TEST_UUID) }.to raise_error( NotImplementedError, /replace/ )
		end

		it "raises an error if it doesn't implement #fetch" do
			expect { store.fetch(TEST_UUID) }.to raise_error( NotImplementedError, /fetch/ )
		end

		it "raises an error if it doesn't implement #each" do
			expect { store.each }.to raise_error( NotImplementedError, /each/ )
		end

		it "raises an error if it doesn't implement #include?" do
			expect { store.include?(TEST_UUID) }.to raise_error( NotImplementedError, /include\?/ )
		end

		it "raises an error if it doesn't implement #each_oid" do
			expect { store.each_oid }.to raise_error( NotImplementedError, /each_oid/ )
		end

		it "raises an error if it doesn't implement #remove" do
			expect { store.remove(TEST_UUID) }.to raise_error( NotImplementedError, /remove/ )
		end

		it "provides a transactional block method" do
			expect {|block| store.transaction(&block) }.to yield_with_no_args
		end

	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
