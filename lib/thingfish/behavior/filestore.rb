#!/usr/bin/env ruby

require 'rspec'
require 'stringio'

require 'thingfish'
require 'thingfish/filestore'
require 'thingfish/testconstants'


share_examples_for "a filestore" do

	include ThingFish::TestConstants

	let( :testio ) do
		StringIO.new( TEST_RESOURCE_CONTENT )
	end

	it "returns nil for non-existant entry" do
	    filestore.fetch( TEST_UUID ).should == nil
	end

	it "returns data for existing entries" do
	    filestore.store_io( TEST_UUID, testio )
		filestore.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "returns data for existing entries stored by UUID object" do
	    filestore.store_io( TEST_UUID_OBJ, testio )
		filestore.fetch_io( TEST_UUID ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "returns data for existing entries fetched by UUID object" do
	    filestore.store_io( TEST_UUID, testio )
		filestore.fetch_io( TEST_UUID_OBJ ) do |io|
			io.read.should == TEST_RESOURCE_CONTENT
		end
	end

	it "deletes requested items" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.delete( TEST_UUID ).should be_true
		filestore.fetch( TEST_UUID ).should be_nil
	end

	it "deletes requested items by UUID object" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.delete( TEST_UUID_OBJ ).should be_true
		filestore.fetch( TEST_UUID ).should be_nil
	end

	it "silently ignores deletes of non-existant keys" do
		filestore.delete( 'porksausage' ).should be_false
	end

	it "returns false when checking has_file? for a file it does not have" do
		filestore.has_file?( TEST_UUID ).should be_false
	end

	it "returns true when checking has_file? for a file it has" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.has_file?( TEST_UUID ).should be_true
	end

	it "returns true when checking has_file? for a file it has by UUID object" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.has_file?( TEST_UUID_OBJ ).should be_true
	end

	it "returns false when checking has_file? for a file which has been deleted" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.delete( TEST_UUID )
		filestore.has_file?( TEST_UUID ).should be_false
	end

	it "knows what the size of any of its stored resources is" do
		filestore.store( TEST_UUID, TEST_RESOURCE_CONTENT )
		filestore.size( TEST_UUID ).should == TEST_RESOURCE_CONTENT.length
		filestore.size( TEST_UUID_OBJ ).should == TEST_RESOURCE_CONTENT.length
	end

	it "returns nil when asked for the size of a resource it doesn't contain" do
		filestore.size( TEST_UUID ).should == nil
	end

end

