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


include ThingFish::TestConstants
include ThingFish::TestHelpers


#####################################################################
###	E X A M P L E S
#####################################################################

describe ThingFish::Resource do

	TEST_METADATA = {
		'format' => 'image/jpeg',
		'title' => 'The Way it Was.jpg',
		'author' => 'Semilin P. Idsnitch',
		'extent' => 134622,
		
	}

	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end

	after( :all ) do
		ThingFish.reset_logger
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



	### Client interface
	describe " -- client interface" do
	
		before( :each ) do
			@io = StringIO.new( TEST_CONTENT )
			@client = mock( "Mock client" )
		end
		

		it "uses its associated client to save changes to metadata" do
			resource = ThingFish::Resource.new( @io, @client )
			
			@client.should_receive( :store ).with( resource ).
				and_return( true )
			
			resource.save.should be_true()
		end
		
		it "raises an error when saving without an associated ThingFish::Client" do
			resource = ThingFish::Resource.new( @io )
			
			lambda { resource.save }.should raise_error( ThingFish::ResourceError, /no client/i )
		end
	
	end

	### User interface
	describe " -- user interface" do

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

	end

end

# vim: set nosta noet ts=4 sw=4:
