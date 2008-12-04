#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/metastore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


describe "A MetaStore", :shared => true do
	include ThingFish::TestConstants,
	        ThingFish::SpecHelpers

	unless defined?( TEST_DUMPSTRUCT )
		TEST_DUMPSTRUCT = {
			TEST_UUID => {
				:title => TEST_TITLE,
				:bitrate => '160',
				:namespace => 'devlibrary',
			},

			TEST_UUID2 => {
				:title => TEST_TITLE,
				:namespace => 'private',
			},
		}
	end


	it "can set and get a property belonging to a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can set a property belonging to a UUID object" do
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can set multiple properties for a UUID" do
		@store.set_property( TEST_UUID, 'cake', 'is a lie' )
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}
		@store.set_properties( TEST_UUID, props )
		@store.get_property( TEST_UUID, TEST_PROP ).should  == TEST_PROPVALUE
		@store.get_property( TEST_UUID, TEST_PROP2 ).should == TEST_PROPVALUE2
		@store.get_property( TEST_UUID, 'cake' ).should be_nil()
	end
	
	it "can set update properties for a UUID" do
		@store.set_property( TEST_UUID, 'cake', 'is a lie' )
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}
		@store.update_properties( TEST_UUID, props )
		@store.get_property( TEST_UUID, TEST_PROP ).should  == TEST_PROPVALUE
		@store.get_property( TEST_UUID, TEST_PROP2 ).should == TEST_PROPVALUE2
		@store.get_property( TEST_UUID, 'cake' ).should == 'is a lie'
	end
	
	it "can get a property belonging to a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.get_property( TEST_UUID_OBJ, TEST_PROP ).should == TEST_PROPVALUE
	end

	it "can test whether or not a property exists for a UUID" do
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_true
	end

	it "can test whether or not a UUID has any metadata stored" do
		@store.has_uuid?( TEST_UUID ).should be_false
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.has_uuid?( TEST_UUID ).should be_true
	end

	it "can test whether or not a UUID (as an object) has any metadata stored" do
		@store.has_uuid?( TEST_UUID_OBJ ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_uuid?( TEST_UUID_OBJ ).should be_true
	end

	it "can test whether or not a property exists for a UUID object" do
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_true
	end

	it "can return the entire set of properties for a UUID" do
		@store.get_properties( TEST_UUID ).should be_empty
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end

	it "can get the entire set of properties for a UUID object" do
		@store.get_properties( TEST_UUID_OBJ ).should be_empty
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID_OBJ ).should have_key( TEST_PROP2.to_sym )
	end

	it "can set the entire set of properties for a UUID object" do
		@store.get_properties( TEST_UUID ).should be_empty
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP.to_sym )
		@store.get_properties( TEST_UUID ).should have_key( TEST_PROP2.to_sym )
	end

	it "can remove a property for a UUID" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_property( TEST_UUID, TEST_PROP )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_true
	end

	it "can remove a property for a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_property( TEST_UUID_OBJ, TEST_PROP )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_true
	end

	it "can remove all properties for a UUID" do
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_resource( TEST_UUID )
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP2 ).should be_false
	end

	it "can remove a set of properties for a UUID" do
		@store.set_property( TEST_UUID_OBJ, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID_OBJ, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_properties( TEST_UUID, TEST_PROP )
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID_OBJ, TEST_PROP2 ).should be_true
	end

	it "can remove a set of properties for a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_properties( TEST_UUID_OBJ, TEST_PROP2 )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_true
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end

	it "can remove all properties for a UUID object" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.delete_resource( TEST_UUID_OBJ )
		@store.has_property?( TEST_UUID, TEST_PROP ).should be_false
		@store.has_property?( TEST_UUID, TEST_PROP2 ).should be_false
	end

	it "can fetch all keys for all properties in the store" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_all_property_keys.should include( TEST_PROP.to_sym )
		@store.get_all_property_keys.should include( TEST_PROP2.to_sym )
	end
	
	
	it "can fetch all values for a given key in the store" do
		@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		@store.set_property( TEST_UUID2, TEST_PROP, TEST_PROPVALUE2 )
		@store.set_property( TEST_UUID3, TEST_PROP, TEST_PROPVALUE2 )
		@store.set_property( TEST_UUID, TEST_PROP2, TEST_PROPVALUE2 )
		@store.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE )
		@store.get_all_property_values( TEST_PROP ).should include( TEST_PROPVALUE2 )
	end
	
	
	# Searching APIs
	
	it "can find UUID by single-property exact match" do
		@store.set_property( TEST_UUID, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :title, 'Squonk the Sea-Ranger' )

		found = @store.find_by_exact_properties( 'title' => TEST_TITLE )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end


	it "can find UUIDs by multi-property exact match" do
		@store.set_property( TEST_UUID,  :title, TEST_TITLE )
		@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		@store.set_property( TEST_UUID2, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :namespace, 'private' )

		found = @store.find_by_exact_properties(
		 	'title'    => TEST_TITLE,
			'namespace' => 'devlibrary'
		  )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end


	it "can find UUIDs by multi-property wildcard match" do
		@store.set_property( TEST_UUID,  :title, TEST_TITLE )
		@store.set_property( TEST_UUID,  :bitrate, '160' )
		@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		@store.set_property( TEST_UUID2, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :namespace, 'private' )

		found = @store.find_by_matching_properties(
		 	'title'     => '*panda*',
			'namespace' => 'dev*',
			'bitrate'   => 160
		  )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end


	it "can find UUIDs by multi-property wildcard match with multiple values for a single key" do
		@store.set_property( TEST_UUID,  :title, TEST_TITLE )
		@store.set_property( TEST_UUID,  :bitrate, '160' )
		@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		@store.set_property( TEST_UUID2, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :namespace, 'private' )

		found = @store.find_by_matching_properties(
		 	'title'     => '*panda*',
			'namespace' => ['dev*', '*y'],
			'bitrate'   => 160
		  )
		
		found.should have(1).members
		found.first.should == TEST_UUID
	end

	
	it "can iterate over all of its resources, yielding them as uuid/prophash pairs" do
		@store.set_property( TEST_UUID,  :title, TEST_TITLE )
		@store.set_property( TEST_UUID,  :bitrate, '160' )
		@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

		@store.set_property( TEST_UUID2, :title, TEST_TITLE )
		@store.set_property( TEST_UUID2, :namespace, 'private' )
		
		results = {}
		@store.each_resource do |uuid, properties|
			results[ uuid ] = properties
		end
		
		results.should have(2).members
		results.keys.should include( TEST_UUID, TEST_UUID2 )
		results[ TEST_UUID ].keys.should have(3).members 
		results[ TEST_UUID ][:title].should == TEST_TITLE
		results[ TEST_UUID ][:bitrate].should == '160'
		results[ TEST_UUID ][:namespace].should == 'devlibrary'
		
		results[ TEST_UUID2 ].keys.should have(2).members 
		results[ TEST_UUID2 ][:title].should == TEST_TITLE
		results[ TEST_UUID2 ][:namespace].should == 'private'
	end
	


	describe "import/export/migration API" do

		it "can dump the contents of the store as a Hash" do
			@store.set_property( TEST_UUID,  :title, TEST_TITLE )
			@store.set_property( TEST_UUID,  :bitrate, '160' )
			@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			@store.set_property( TEST_UUID2, :title, TEST_TITLE )
			@store.set_property( TEST_UUID2, :namespace, 'private' )

			dumpstruct = @store.transaction { @store.dump_store }

			dumpstruct.should be_an_instance_of( Hash )
			# dumpstruct.keys.should == [ TEST_UUID, TEST_UUID2 ] # For debugging only
			dumpstruct.keys.should have(2).members
			dumpstruct.keys.should include( TEST_UUID, TEST_UUID2 )

			dumpstruct[ TEST_UUID ].should be_an_instance_of( Hash )
			dumpstruct[ TEST_UUID ].keys.should have(3).members
			dumpstruct[ TEST_UUID ].keys.should include( :title, :bitrate, :namespace )
			dumpstruct[ TEST_UUID ].values.should include( TEST_TITLE, '160', 'devlibrary' )
			
			dumpstruct[ TEST_UUID2 ].should be_an_instance_of( Hash )
			dumpstruct[ TEST_UUID2 ].keys.should have(2).members
			dumpstruct[ TEST_UUID2 ].keys.should include( :title, :namespace )
			dumpstruct[ TEST_UUID2 ].values.should include( TEST_TITLE, 'private' )
		end

		it "clears any current metadata when loading a metastore dump" do
			@store.set_property( TEST_UUID,  :title, TEST_TITLE )
			@store.set_property( TEST_UUID,  :bitrate, '160' )
			@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			@store.set_property( TEST_UUID2, :title, TEST_TITLE )
			@store.set_property( TEST_UUID2, :namespace, 'private' )

			@store.transaction { @store.load_store({}) }
			
			@store.should_not have_uuid( TEST_UUID )
			@store.should_not have_uuid( TEST_UUID2 )
		end

		it "can load the store from a Hash" do
			@store.transaction { @store.load_store(TEST_DUMPSTRUCT) }
			
			@store.get_property( TEST_UUID,  :title ).should == TEST_TITLE
			@store.get_property( TEST_UUID,  :bitrate ).should == '160'
			@store.get_property( TEST_UUID,  :namespace ).should == 'devlibrary'

			@store.get_property( TEST_UUID2, :title ).should == TEST_TITLE
			@store.get_property( TEST_UUID2, :namespace ).should == 'private'
		end
		
		
		it "can migrate directly from another metastore" do
			other_store = mock( "other metastore mock" )
			expectation = other_store.should_receive( :migrate )
			TEST_DUMPSTRUCT.each do |uuid, properties|
				expectation.and_yield( uuid, properties )
			end
			
			@store.migrate_from( other_store )

			@store.get_property( TEST_UUID,  :title ).should == TEST_TITLE
			@store.get_property( TEST_UUID,  :bitrate ).should == '160'
			@store.get_property( TEST_UUID,  :namespace ).should == 'devlibrary'

			@store.get_property( TEST_UUID2, :title ).should == TEST_TITLE
			@store.get_property( TEST_UUID2, :namespace ).should == 'private'
		end

		it "helps another metastore migrate its data" do
			@store.set_property( TEST_UUID,  :title, TEST_TITLE )
			@store.set_property( TEST_UUID,  :bitrate, '160' )
			@store.set_property( TEST_UUID,  :namespace, 'devlibrary' )

			@store.set_property( TEST_UUID2, :title, TEST_TITLE )
			@store.set_property( TEST_UUID2, :namespace, 'private' )

			results = {}
			@store.migrate do |uuid, properties|
				results[ uuid ] = properties
			end
			
			results.should have(2).members
			results.keys.should include( TEST_UUID, TEST_UUID2 )
			results[ TEST_UUID ].keys.should have(3).members 
			results[ TEST_UUID ][:title].should == TEST_TITLE
			results[ TEST_UUID ][:bitrate].should == '160'
			results[ TEST_UUID ][:namespace].should == 'devlibrary'

			results[ TEST_UUID2 ].keys.should have(2).members 
			results[ TEST_UUID2 ][:title].should == TEST_TITLE
			results[ TEST_UUID2 ][:namespace].should == 'private'
		end

	end
	

	describe " (safety methods)" do
		
		it "eliminates system attributes from properties passed through #set_safe_properties" do
			@store.set_properties( TEST_UUID, TEST_PROPSET )
			
			@store.set_safe_properties( TEST_UUID, 
				:extent => "0",
				:checksum => '',
				TEST_PROP => 'something else'
			  )
			
			@store.get_property( TEST_UUID, 'extent' ).should == TEST_PROPSET['extent']
			@store.get_property( TEST_UUID, 'checksum' ).should == TEST_PROPSET['checksum']
			@store.get_property( TEST_UUID, TEST_PROP ).should == 'something else'
			@store.get_property( TEST_UUID, TEST_PROP2 ).should be_nil()
		end


		it "eliminates system attributes from properties passed through #update_safe_properties" do
			@store.set_properties( TEST_UUID, TEST_PROPSET )
			
			@store.update_safe_properties( TEST_UUID, 
				:extent => "0",
				:checksum => '',
				TEST_PROP => 'something else'
			  )
			
			@store.get_property( TEST_UUID, 'extent' ).should == TEST_PROPSET['extent']
			@store.get_property( TEST_UUID, 'checksum' ).should == TEST_PROPSET['checksum']
			@store.get_property( TEST_UUID, TEST_PROP ).should == 'something else'
		end
		
		
		it "eliminates system attributes from properties passed through #delete_safe_properties" do
			@store.set_properties( TEST_UUID, TEST_PROPSET )
			
			@store.delete_safe_properties( TEST_UUID, :extent, :checksum, TEST_PROP )
			
			@store.should have_property( TEST_UUID, 'extent' )
			@store.should have_property( TEST_UUID, 'checksum' )
			@store.should_not have_property( TEST_UUID, TEST_PROP )
		end


		it "sets properties safely via #set_safe_property" do
			@store.set_safe_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
			@store.get_property( TEST_UUID, TEST_PROP ).should == TEST_PROPVALUE			
		end
		
		
		it "refuses to update system properties via #set_safe_property" do
			lambda {
				@store.set_safe_property( TEST_UUID, 'extent', 0 )
			}.should raise_error( ThingFish::MetaStoreError, /used by the system/ )
		end

		
		it "deletes properties safely via #set_safe_property" do
			@store.set_property( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
			@store.delete_safe_property( TEST_UUID, TEST_PROP )
			@store.has_property?( TEST_UUID, TEST_PROP ).should be_false			
		end
		

		it "refuses to delete system properties via #delete_safe_property" do
			lambda {
				@store.delete_safe_property( TEST_UUID, 'extent' )
			}.should raise_error( ThingFish::MetaStoreError, /used by the system/ )
		end
	end
	
	
	# Transaction API
	
	it "can execute a block in the context of a transaction" do
		ran_block = false
		@store.transaction do
			ran_block = true
		end
		
		ran_block.should be_true()
	end


end

