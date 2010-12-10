#!/usr/bin/env ruby

require 'rspec'

require 'thingfish'
require 'thingfish/behavior/metastore'
require 'thingfish/constants'
require 'thingfish/metastore'


share_examples_for "an advanced metastore" do

	it_should_behave_like "a metastore"

	TEST_TITLE = 'Wearable the Walleye Goes It Alone'


	context "set-fetching API" do

		before( :each ) do

			@uuids = []
			@uuid_titles = {}

			20.times do |i|
				uuid = UUIDTools::UUID.timestamp_create
				title = "%s (%s)" % [ TEST_TITLE, Digest::MD5.hexdigest(uuid) ]

				metastore.set_property( uuid,  :title, title )
				metastore.set_property( uuid,  :bitrate, '160' )
				metastore.set_property( uuid,  :namespace, 'devlibrary' )

				@uuids << uuid.to_s
				@uuid_titles[ uuid.to_s ] = title
			end
		end

		it "can fetch a set of resources in natural order with no limit" do
			results = metastore.get_resource_set

			results.should have( 20 ).members

			results.collect {|tuple| tuple[0] }.should include( *@uuids )
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should include( *@uuid_titles.values )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with a limit" do
			results = metastore.get_resource_set( [], 5 )

			results.should have( 5 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 0, 5 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[0, 5] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with a limit and offset" do
			results = metastore.get_resource_set( [], 5, 5 )

			results.should have( 5 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 5, 5 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[5, 5] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in natural order with an offset, but no limit" do
			results = metastore.get_resource_set( [], 0, 5 )

			results.should have( 15 ).members

			results.collect {|tuple| tuple[0] }.should == @uuids[ 5..-1 ]
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.
				should == @uuid_titles.values_at( *@uuids[5..-1] )
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with no limit" do
			results = metastore.get_resource_set( [:title] )

			results.should have( 20 ).members

			results.collect {|tuple| tuple[0] }.should include( *@uuids )
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == @uuid_titles.values.sort
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with a limit" do
			results = metastore.get_resource_set( [:title], 5 )

			results.should have( 5 ).members

			expected_titles = @uuid_titles.values.sort[ 0, 5 ]
			title_uuids = @uuid_titles.invert.values_at( *expected_titles )

			results.collect {|tuple| tuple[0] }.should == title_uuids
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == expected_titles
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with a limit and offset" do
			results = metastore.get_resource_set( [:title], 5, 5 )

			results.should have( 5 ).members

			expected_titles = @uuid_titles.values.sort[ 5, 5 ]
			title_uuids = @uuid_titles.invert.values_at( *expected_titles )

			results.collect {|tuple| tuple[0] }.should == title_uuids
			results.collect {|tuple| tuple[1][:namespace] }.uniq.should == ['devlibrary']
			results.collect {|tuple| tuple[1][:title] }.should == expected_titles
			results.collect {|tuple| tuple[1][:bitrate] }.uniq.should == ['160']
		end

		it "can fetch a set of resources in sorted order with an offset, but no limit" do
			results = metastore.get_resource_set( [:title], 0, 5 )

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

