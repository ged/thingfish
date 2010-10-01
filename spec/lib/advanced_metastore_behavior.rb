#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/metastore_behavior'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/metastore'

include ThingFish::TestConstants

describe "An advanced MetaStore", :shared => true do
	include ThingFish::SpecHelpers

	it_should_behave_like "A MetaStore"


	describe "set-fetching API" do
		before( :each ) do
			pending "Fixes in Redland to support DESCRIBE and/or CONSTRUCT with LIMIT/ORDER"

			@uuids = []
			@uuid_titles = {}

			20.times do |i|
				uuid = UUIDTools::UUID.timestamp_create
				title = "%s (%s)" % [ TEST_TITLE, Digest::MD5.hexdigest(uuid) ]

				@store.set_property( uuid,  :title, title )
				@store.set_property( uuid,  :bitrate, '160' )
				@store.set_property( uuid,  :namespace, 'devlibrary' )

				@uuids << uuid.to_s
				@uuid_titles[ uuid.to_s ] = title
			end
		end

		it "can fetch a set of resources in natural order with no limit" do
			results = @store.get_resource_set

			results.should have( 20 ).members

			results.collect {|tuple| tuple[0] }.should include( *@uuids )
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should include( *@uuid_titles.values )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with a limit" do
			results = @store.get_resource_set( [], 5 )

			results.should have( 5 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 0, 5 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[0, 5] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with a limit and offset" do
			results = @store.get_resource_set( [], 5, 5 )

			results.should have( 5 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 5, 5 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[5, 5] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with an offset, but no limit" do
			results = @store.get_resource_set( [], 0, 5 )

			results.should have( 15 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 5..-1 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[5..-1] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with no limit" do
			results = @store.get_resource_set( [:title] )

			results.should have( 20 ).members

			results.collect {|tuple| tuple[0] }.should include( *@uuids )
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == @uuid_titles.values.sort
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with a limit" do
			results = @store.get_resource_set( [:title], 5 )

			results.should have( 5 ).members

			expected_titles = @uuid_titles.values.sort[ 0, 5 ]
			title_uuids = @uuid_titles.invert.values_at( *expected_titles )

			results.collect {|tuple| tuple[0] }.should == title_uuids
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == expected_titles
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with a limit and offset" do
			results = @store.get_resource_set( [:title], 5, 5 )

			results.should have( 5 ).members

			expected_titles = @uuid_titles.values.sort[ 5, 5 ]
			title_uuids = @uuid_titles.invert.values_at( *expected_titles )

			results.collect {|tuple| tuple[0] }.should == title_uuids
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == expected_titles
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with an offset, but no limit" do
			results = @store.get_resource_set( [:title], 0, 5 )

			results.should have( 15 ).members

			expected_titles = @uuid_titles.values.sort[ 5..-1 ]
			title_uuids = @uuid_titles.invert.values_at( *expected_titles )

			results.collect {|tuple| tuple[0] }.should == title_uuids
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == expected_titles
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

	end

end

