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
	}

	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
	end


	### Metadata interface

	it "auto-generates accessors for metadata values" do
		resource = ThingFish::Resource.new

		resource.should_not have_extent()
        
		resource.extent = 1024
		resource.extent.should == 1024
	    
		resource.should have_extent()
		resource.should_not have_pudding() # Awwww... no pudding.
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


	### Client interface
	describe "created with an associated client object" do
	
		before( :each ) do
			@resource = ThingFish::Resource.new( nil, @client, TEST_UUID )
		end
		

		it "uses its associated client to save changes" do
			@resource.io = @io
			@client.should_receive( :store_data ).with( @io ).
				and_return( @resource )
			@client.should_receive( :store_metadata ).with( @resource.metadata ).
				and_return( @resource )

			@resource.save.should == @resource
		end
		
		
		it "loads its data from the client on demand" do
			@client.should_receive( :fetch_data ).with( TEST_UUID ).
				and_return( :the_data )

			@resource.io.should == :the_data
		end
		
	end


	describe "created with an IO and an associated client object" do
		before( :each ) do
			@resource = ThingFish::Resource.new( @io, @client, TEST_UUID )
		end

		it "can discard local metadata changes in favor of the server-side version" do
			@resource.energy = 'legs'
			@client.should_receive( :fetch_metadata ).with( TEST_UUID ).
				and_return( :new_metadata )
			@resource.revert
			@resource.metadata.should == :new_metadata
		end
		
		
		it "can discard local changes to the data in favor of the server-side version" do
			@resource.revert
			@client.should_receive( :fetch_data ).with( TEST_UUID ).
				and_return( :a_new_io )
			@resource.revert
			@resource.io.should == :a_new_io
		end
		
	end

end

# vim: set nosta noet ts=4 sw=4:
