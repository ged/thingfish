#!/usr/bin/env ruby

require 'rspec'

require 'thingfish'
require 'thingfish/metastore'
require 'thingfish/testconstants'


share_examples_for "a metastore" do
	include ThingFish::TestConstants

	unless defined?( TEST_DUMPSTRUCT )
		TEST_DUMPSTRUCT = {
			ThingFish::TestConstants::TEST_UUID => {
				:title => ThingFish::TestConstants::TEST_TITLE,
				:bitrate => '160',
				:namespace => 'devlibrary',
			},

			ThingFish::TestConstants::TEST_UUID2 => {
				:title => ThingFish::TestConstants::TEST_TITLE,
				:namespace => 'private',
			},
		}
	end


	it "can set and get a property belonging to a UUID" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can set a property belonging to a UUID object" do
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		metastore.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can set multiple properties for a UUID" do
		metastore.set_property( TEST_UUID, 'cake', 'is a lie' )
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}
		metastore.set_properties( TEST_UUID, props )
		metastore.get_property( TEST_UUID, TEST_PROP ).should  == TEST_PROPVALUE
		metastore.get_property( TEST_UUID, TEST_PROP2 ).should == TEST_PROPVALUE2
		metastore.get_property( TEST_UUID, 'cake' ).should be_nil()
	end

	it "can set update properties for a UUID" do
		metastore.set_property( TEST_UUID, 'cake', 'is a lie' )
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}
		metastore.update_properties( TEST_UUID, props )
		metastore.get_property( TEST_UUID, TEST_PROP ).should  == TEST_PROPVALUE
		metastore.get_property( TEST_UUID, TEST_PROP2 ).should == TEST_PROPVALUE2
		metastore.get_property( TEST_UUID, 'cake' ).should == 'is a lie'
	end

	it "can get a property belonging to a UUID object" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.get_property( TEST_UUID_OBJ, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can test whether or not a property exists for a UUID" do
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_false
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_true
	end

	it "can test whether or not a UUID has any metadata stored" do
		metastore.has_uuid?( TEST_UUID ).should be_false
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		metastore.has_uuid?( TEST_UUID ).should be_true
	end

	it "can test whether or not a UUID (as an object) has any metadata stored" do
		metastore.has_uuid?( TEST_UUID_OBJ ).should be_false
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.has_uuid?( TEST_UUID_OBJ ).should be_true
	end

	it "can test whether or not a property exists for a UUID object" do
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_true
	end

	it "can return the entire set of properties for a UUID" do
		metastore.get_properties( TEST_UUID ).should be_empty
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		metastore.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end

	it "can get the entire set of properties for a UUID object" do
		metastore.get_properties( TEST_UUID_OBJ ).should be_empty
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP.to_sym )
		metastore.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP2.to_sym )
	end

	it "can set the entire set of properties for a UUID object" do
		metastore.get_properties( TEST_UUID ).should be_empty
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		metastore.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end

	it "can remove a property for a UUID" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_property( TEST_UUID, TEST_PROP )
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_false
		metastore.has_property?( TEST_UUID, TEST_PROP2 ).should be_true
	end

	it "can remove a property for a UUID object" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_property( TEST_UUID_OBJ, TEST_PROP )
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_false
		metastore.has_property?( TEST_UUID, TEST_PROP2 ).should be_true
	end

	it "can remove all properties for a UUID" do
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_resource( TEST_UUID )
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP2 ).should be_false
	end

	it "can remove a set of properties for a UUID" do
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_properties( TEST_UUID, TEST_PROP )
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		metastore.has_property?( TEST_UUID_OBJ, TEST_PROP2 ).should be_true
	end

	it "can remove a set of properties for a UUID object" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_properties( TEST_UUID_OBJ, TEST_PROP2 )
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_true
		metastore.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end

	it "can remove all properties for a UUID object" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.delete_resource( TEST_UUID_OBJ )
		metastore.has_property?( TEST_UUID, TEST_PROP ).should be_false
		metastore.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end

	it "can fetch all keys for all properties in the store" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.get_all_property_keys.should include( TEST_PROP.to_sym )
		metastore.get_all_property_keys.should include( TEST_PROP2.to_sym )
	end


	it "can fetch all values for a given key in the store" do
		metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		metastore.set_property( TEST_UUID2, TEST_PROP, TEST_PROPVALUE2 )
		metastore.set_property( TEST_UUID3, TEST_PROP, TEST_PROPVALUE2 )
		metastore.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		metastore.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE )
		metastore.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE2 )
	end


	# Searching APIs

	it "can find tuples by single-property exact match" do
		metastore.set_property( TEST_UUID, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = metastore.find_by_exact_properties( 'title' => TEST_TITLE )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
	end


	it "can find tuples by single-property case insensitive exact match" do
		metastore.set_property( TEST_UUID, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = metastore.find_by_exact_properties( 'title' => TEST_TITLE.downcase )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
	end


	it "can find ordered tuples by single-property exact match" do
		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )
		metastore.set_property( TEST_UUID2, :description, 'Another description.' )

		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )
		metastore.set_property( TEST_UUID,  :description, 'This is a description.' )

		found = metastore.find_by_exact_properties( {'title' => TEST_TITLE}, ['description'] )

		found.should have(2).members
		found.first[0] == TEST_UUID2
		found.last[0]  == TEST_UUID
	end


	it "returns tuples in UUID order from a single-property exact match with no other order attributes" do
		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )
		metastore.set_property( TEST_UUID2, :description, 'Another description.' )

		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )
		metastore.set_property( TEST_UUID,  :description, 'This is a description.' )

		found = metastore.find_by_exact_properties( {'title' => TEST_TITLE}, [] )

		found.should have(2).members
		found.map {|tuple| tuple.first }.should == [ TEST_UUID, TEST_UUID2 ].sort
	end


	it "can return a subset of found exact-match tuples" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		found = metastore.find_by_exact_properties( {'title' => TEST_TITLE}, [:namespace], 1 )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
		properties[:namespace].should == 'devlibrary'
	end


	it "can return an offset subset of found exact-match tuples" do
		uuids = []
		20.times do |i|
			uuid = UUIDTools::UUID.timestamp_create
			uuids << uuid
			title = TEST_TITLE + " (Episode %02d)" % [ i + 1 ]
			metastore.set_property( uuid, :title, title )
			metastore.set_property( uuid, :namespace, 'devlibrary' )
		end

		0.step( 15, 5 ) do |offset|
			found = metastore.find_by_exact_properties( {'namespace' => 'devlibrary'}, [:title], 5, offset )

			found.should have( 5 ).members
			uuid, props = *found.first
			uuid.should == uuids[ offset ].to_s
			props[:title].should == TEST_TITLE + " (Episode %02d)" % [ offset + 1 ]
		end
	end


	it "returns an empty array for offsets that exceed the number of results" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		found = metastore.find_by_exact_properties( {'namespace' => 'private'}, [], 10, 1 )

		found.should be_empty()
	end


	it "can find tuples by multi-property exact match" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		found = metastore.find_by_exact_properties(
		 	'title'    => TEST_TITLE,
			'namespace' => 'devlibrary'
		  )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
		properties[:namespace].should == 'devlibrary'
	end


	it "can find tuples by single-property wildcard match" do
		metastore.set_property( TEST_UUID, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = metastore.find_by_matching_properties( 'title' => 'Muffin*' )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
	end


	it "can find tuples by single-property case insensitive wildcard match" do
		metastore.set_property( TEST_UUID, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = metastore.find_by_matching_properties( 'title' => 'muffin*' )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
	end


	it "can find tuples by multi-property wildcard match" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :bitrate, '160' )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		found = metastore.find_by_matching_properties(
		 	'title'     => '*panda*',
			'namespace' => 'dev*',
			'bitrate'   => 160
		  )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
		properties[:namespace].should == 'devlibrary'
		properties[:bitrate].should == '160'
	end


	it "can find tuples by multi-property wildcard match with multiple values for a single key" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :bitrate, '160' )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		found = metastore.find_by_matching_properties(
		 	'title'     => '*panda*',
			'namespace' => ['dev*', '*y'],
			'bitrate'   => 160
		  )

		found.should have(1).members
		uuid, properties = found.first

		uuid.should == TEST_UUID
		properties[:title].should == TEST_TITLE
		properties[:namespace].should == 'devlibrary'
		properties[:bitrate].should == '160'
	end


	it "can iterate over all of its resources, yielding them as uuid/prophash pairs" do
		metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
		metastore.set_property( TEST_UUID,  :bitrate, '160' )
		metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
		metastore.set_property( TEST_UUID2, :namespace, 'private' )

		results = {}
		metastore.each_resource do |uuid, properties|
			results[ uuid ] = properties
		end

		results.should have(2).members
		results.keys.should include( TEST_UUID, TEST_UUID2 )
		results[ TEST_UUID ].keys.should have_at_least(3).members
		results[ TEST_UUID ][:title].should == TEST_TITLE
		results[ TEST_UUID ][:bitrate].should == '160'
		results[ TEST_UUID ][:namespace].should == 'devlibrary'

		results[ TEST_UUID2 ].keys.should have_at_least(2).members
		results[ TEST_UUID2 ][:title].should == TEST_TITLE
		results[ TEST_UUID2 ][:namespace].should == 'private'
	end

	describe "import/export/migration API" do

		it "can dump the contents of the store as a Hash" do
			metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
			metastore.set_property( TEST_UUID,  :bitrate, '160' )
			metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
			metastore.set_property( TEST_UUID2, :namespace, 'private' )

			dumpstruct = metastore.transaction { metastore.dump_store }

			dumpstruct.should be_an_instance_of( Hash )
			# dumpstruct.keys.should == [ TEST_UUID, TEST_UUID2 ] # For debugging only
			dumpstruct.keys.should have(2).members
			dumpstruct.keys.should include( TEST_UUID, TEST_UUID2 )

			dumpstruct[ TEST_UUID ].should be_an_instance_of( Hash )
			dumpstruct[ TEST_UUID ].keys.should have_at_least(3).members
			dumpstruct[ TEST_UUID ].keys.should include( :title, :bitrate, :namespace )
			dumpstruct[ TEST_UUID ].values.should include( TEST_TITLE, '160', 'devlibrary' )

			dumpstruct[ TEST_UUID2 ].should be_an_instance_of( Hash )
			dumpstruct[ TEST_UUID2 ].keys.should have_at_least(2).members
			dumpstruct[ TEST_UUID2 ].keys.should include( :title, :namespace )
			dumpstruct[ TEST_UUID2 ].values.should include( TEST_TITLE, 'private' )
		end

		it "clears any current metadata when loading a metastore dump" do
			metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
			metastore.set_property( TEST_UUID,  :bitrate, '160' )
			metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
			metastore.set_property( TEST_UUID2, :namespace, 'private' )

			metastore.transaction { metastore.load_store({}) }

			metastore.should_not have_uuid( TEST_UUID )
			metastore.should_not have_uuid( TEST_UUID2 )
		end

		it "can load the store from a Hash" do
			metastore.transaction { metastore.load_store(TEST_DUMPSTRUCT) }

			metastore.get_property( TEST_UUID,  :title ).should == TEST_TITLE
			metastore.get_property( TEST_UUID,  :bitrate ).should == '160'
			metastore.get_property( TEST_UUID,  :namespace ).should == 'devlibrary'

			metastore.get_property( TEST_UUID2, :title ).should == TEST_TITLE
			metastore.get_property( TEST_UUID2, :namespace ).should == 'private'
		end


		it "can migrate directly from another metastore" do
			other_store = mock( "other metastore mock" )
			expectation = other_store.should_receive( :migrate )
			TEST_DUMPSTRUCT.each do |uuid, properties|
				expectation.and_yield( uuid, properties )
			end

			metastore.migrate_from( other_store )

			metastore.get_property( TEST_UUID,  :title ).should == TEST_TITLE
			metastore.get_property( TEST_UUID,  :bitrate ).should == '160'
			metastore.get_property( TEST_UUID,  :namespace ).should == 'devlibrary'

			metastore.get_property( TEST_UUID2, :title ).should == TEST_TITLE
			metastore.get_property( TEST_UUID2, :namespace ).should == 'private'
		end

		it "helps another metastore migrate its data" do
			metastore.set_property( TEST_UUID,  :title, TEST_TITLE )
			metastore.set_property( TEST_UUID,  :bitrate, '160' )
			metastore.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			metastore.set_property( TEST_UUID2, :title, TEST_TITLE )
			metastore.set_property( TEST_UUID2, :namespace, 'private' )

			results = {}
			metastore.migrate do |uuid, properties|
				results[ uuid ] = properties
			end

			results.should have_at_least(2).members
			results.keys.should include( TEST_UUID, TEST_UUID2 )
			results[ TEST_UUID ].keys.should have_at_least(3).members
			results[ TEST_UUID ][:title].should == TEST_TITLE
			results[ TEST_UUID ][:bitrate].should == '160'
			results[ TEST_UUID ][:namespace].should == 'devlibrary'

			results[ TEST_UUID2 ].keys.should have_at_least(2).members
			results[ TEST_UUID2 ][:title].should == TEST_TITLE
			results[ TEST_UUID2 ][:namespace].should == 'private'
		end

	end


	describe " (safety methods)" do

		it "eliminates system attributes from properties passed through #set_safe_properties" do
			metastore.set_properties( TEST_UUID, TEST_PROPSET )

			metastore.set_safe_properties( TEST_UUID, 
				:extent => "0",
				:checksum => '',
				TEST_PROP => 'something else'
			  )

			metastore.get_property( TEST_UUID, 'extent' ).should == TEST_PROPSET['extent']
			metastore.get_property( TEST_UUID, 'checksum' ).should == TEST_PROPSET['checksum']
			metastore.get_property( TEST_UUID, TEST_PROP ).should == 'something else'
			metastore.get_property( TEST_UUID, TEST_PROP2 ).should be_nil()
		end


		it "eliminates system attributes from properties passed through #update_safe_properties" do
			metastore.set_properties( TEST_UUID, TEST_PROPSET )

			metastore.update_safe_properties( TEST_UUID, 
				:extent => "0",
				:checksum => '',
				TEST_PROP => 'something else'
			  )

			metastore.get_property( TEST_UUID, 'extent' ).should == TEST_PROPSET['extent']
			metastore.get_property( TEST_UUID, 'checksum' ).should == TEST_PROPSET['checksum']
			metastore.get_property( TEST_UUID, TEST_PROP ).should == 'something else'
		end


		it "eliminates system attributes from properties passed through #delete_safe_properties" do
			metastore.set_properties( TEST_UUID, TEST_PROPSET )

			metastore.delete_safe_properties( TEST_UUID, :extent, :checksum, TEST_PROP )

			metastore.should have_property( TEST_UUID, 'extent' )
			metastore.should have_property( TEST_UUID, 'checksum' )
			metastore.should_not have_property( TEST_UUID, TEST_PROP )
		end


		it "sets properties safely via #set_safe_property" do
			metastore.set_safe_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
			metastore.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE			
		end


		it "refuses to update system properties via #set_safe_property" do
			lambda {
				metastore.set_safe_property( TEST_UUID, 'extent', 0 )
			}.should raise_error( ThingFish::MetaStoreError, /used by the system/ )
		end


		it "deletes properties safely via #set_safe_property" do
			metastore.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
			metastore.delete_safe_property( TEST_UUID, TEST_PROP )
			metastore.has_property?( TEST_UUID, TEST_PROP ).should be_false			
		end


		it "refuses to delete system properties via #delete_safe_property" do
			lambda {
				metastore.delete_safe_property( TEST_UUID, 'extent' )
			}.should raise_error( ThingFish::MetaStoreError, /used by the system/ )
		end
	end


	# Transaction API

	it "can execute a block in the context of a transaction" do
		ran_block = false
		metastore.transaction do
			ran_block = true
		end

		ran_block.should be_true()
	end


end

