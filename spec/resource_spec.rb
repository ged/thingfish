#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



#####################################################################
###	E X A M P L E S
#####################################################################

describe ThingFish::Resource do
	include ThingFish::TestHelpers,
		ThingFish::TestConstants

	TEST_METADATA = {
		'format' => 'image/jpeg',
		'title' => 'The Way it Was.jpg',
		'author' => 'Semilin P. Idsnitch',
		'extent' => 134622,
		'doodlebops' => 'suck',
		'byline' => 'Something Naughty That Jonathan Will Make Us Change'
	}
	TEST_METADATA.freeze

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	before( :each ) do
		@io = StringIO.new( TEST_CONTENT )
		@client = stub( "Mock client" )
	end
	

	it "can be created from an object that responds to #read" do
		resource = ThingFish::Resource.new( @io )
		resource.io.should == @io
		resource.client.should be_nil()
		resource.uuid.should be_nil()
	end
	

	it "can be created from an IO object and a client object" do
		resource = ThingFish::Resource.new( @io, @client )
		resource.io.should == @io
		resource.client.should == @client
		resource.uuid.should be_nil()
	end


	it "can be create from a Hash of metadata" do
		resource = ThingFish::Resource.new( :title => 'Piewicket Eats a Potato' )
		resource.io.should be_nil()
		resource.client.should be_nil()
		resource.uuid.should be_nil()
		resource.title.should == 'Piewicket Eats a Potato'
	end
	

	it "can be created from an IO object and a Hash of metadata" do
		resource = ThingFish::Resource.new( @io, :title => 'Piewicket Eats a Potato' )
		resource.io.should == @io
		resource.client.should be_nil()
		resource.uuid.should be_nil()
		resource.title.should == 'Piewicket Eats a Potato'
	end
	
	
	it "can be created from an IO object, a client object, and a Hash of metadata" do
		resource = ThingFish::Resource.new( @io, @client, :title => 'Piewicket Eats a Potato' )
		resource.io.should == @io
		resource.client.should == @client
		resource.title.should == 'Piewicket Eats a Potato'
	end


	it "can be created from an IO object, a client object, a UUID, and a Hash of metadata" do
		@client.should_receive( :fetch_metadata ).with( TEST_UUID ).
			and_return( TEST_METADATA.dup )
		resource = ThingFish::Resource.new( @io, @client, TEST_UUID,
		 	:title => 'Piewicket Eats a Potato' )
		resource.io.should == @io
		resource.client.should == @client
		resource.uuid.should == TEST_UUID
		resource.title.should == 'Piewicket Eats a Potato'
	end

	it "raises an error when saving without an associated ThingFish::Client" do
		resource = ThingFish::Resource.new( @io )
		
		lambda {
			resource.save
		  }.should raise_error( ThingFish::ResourceError, /no client/i )
	end


	it "knows that it is always considered unsaved if it doesn't have an associated client" do
		resource = ThingFish::Resource.new( @io )
		resource.saved = true
		resource.should_not be_saved()
	end


	### Metadata interface
	describe "created with no arguments" do
		before( :each ) do
			@resource = ThingFish::Resource.new
		end
		
		
		it "auto-generates accessors for metadata values" do
			@resource.should_not have_extent()
        
			@resource.extent = 1024
			@resource.extent.should == 1024
	    
			@resource.should have_extent()
			@resource.should_not have_pudding() # Awwww... no pudding.
		end


		it "allows one to replace the metadata hash" do
			@resource.metadata = TEST_METADATA

			@resource.metadata.should have(6).members
			@resource.metadata.keys.should include( 'doodlebops', 'title' )
			@resource.metadata.values.
				should include( 'suck', 'Something Naughty That Jonathan Will Make Us Change' )
		end
	
	
		it "returns nil when asked for its data" do
			@resource.data.should be_nil()
		end

		it "allows one to replace the metadata with something that can be cast to a Hash" do
			my_metadata_class = Class.new {
				def initialize( stuff={} )
					@innerhash = stuff
				end
			
				def to_hash
					return @innerhash
				end
			}
		
			@resource.metadata = my_metadata_class.new( TEST_METADATA )

			@resource.metadata.should have(6).members
			@resource.metadata.keys.should include( 'doodlebops', 'title' )
			@resource.metadata.values.
				should include( 'suck', 'Something Naughty That Jonathan Will Make Us Change' )
		end
		
		it "allows one to overwrite the resource's data" do
			@resource.io.should be_nil()
			@resource.data = "newdata"
			@resource.io.rewind
			@resource.io.read.should == "newdata"
		end
		
	end


	### With an IO object
	describe "created with an IO object" do
		
		before( :each ) do
			@io = StringIO.new
			@resource = ThingFish::Resource.new( @io )
		end
		

		it "allows one to overwrite the resource's data" do
			@resource.data = "newdata"
			@resource.io.rewind
			@resource.io.read.should == "newdata"
		end

	end


	### Client interface
	describe "created with an associated client object" do
	
		before( :each ) do
			@resource = ThingFish::Resource.new( nil, @client, TEST_UUID )
		end
		

		it "uses its associated client to save changes" do
			@resource.io = @io
			@client.should_receive( :store_data ).with( @resource ).
				and_return( @resource )
			@client.should_receive( :store_metadata ).with( @resource ).
				and_return( @resource )

			@resource.save.should == @resource
		end
		
		
		it "fetches an IO from the client on demand" do
			@client.should_receive( :fetch_data ).with( TEST_UUID ).
				and_return( :an_io )
			@resource.io.should == :an_io
		end
		

		it "loads its data from the client on demand" do
			io = mock( "mock io" )
			@client.should_receive( :fetch_data ).with( TEST_UUID ).
				and_return( io )
			io.should_receive( :read ).and_return( :the_data )
			@resource.data.should == :the_data
		end
		
	end


	describe "created with an IO and an associated client object" do
		before( :each ) do
			@resource = ThingFish::Resource.new( @io, @client, TEST_UUID )
		end

		it "can discard local metadata changes in favor of the server-side version" do
 			@client.should_receive( :fetch_metadata ).with( TEST_UUID ).twice.
				and_return( TEST_METADATA.dup, TEST_METADATA.dup )
			@resource.energy = 'legs'
			@resource.revert

			@resource.metadata.should == TEST_METADATA
			@resource.metadata.should_not include( 'energy' )
		end
		
		
		it "can discard local changes to the data in favor of the server-side version" do
			@resource.revert
			@client.should_receive( :fetch_data ).with( TEST_UUID ).
				and_return( :a_new_io )
			@resource.revert
			@resource.io.should == :a_new_io
		end
	
	
		it "can read its data from the associated IO object" do
			@io.should_receive( :read ).and_return( :the_data )
			@resource.data.should == :the_data
		end
		
	end

end

# vim: set nosta noet ts=4 sw=4:
