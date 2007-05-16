#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/constants'
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
	include ThingFish::TestConstants

	before(:all) do
		@tmpfile = Tempfile.new( 'test.txt', '.' )
		@tmpfile.print( TEST_CONTENT )
		@tmpfile.close
	end

	after(:all) do
		@tmpfile.delete
	end


	before do
		@io = StringIO.new( TEST_CONTENT )
	end


	### Examples
	it "can be created from an IO" do
		resource = ThingFish::Resource.new( @io )
		resource.data.should == TEST_CONTENT
	end
	
	
	it "can be created with metadata" do
		resource = ThingFish::Resource.new( @io, :author => "Heidi Escariot" )
		resource.author.should == "Heidi Escariot"
	end


	it "can be created from a file" do
		resource = ThingFish::Resource.from_file( @tmpfile.path )
		resource.data.should == TEST_CONTENT
	end
	
	
	it "can be created from a Net::HTTPResponse" do
		resource = nil
		with_fixtured_http_ok_response( TEST_CONTENT ) do |response|
			resource = ThingFish::Resource.from_http_response( response )
		end
		resource.data.should == TEST_CONTENT
	end

	it "should raise an error if created with a non-200 HTTPResponse" do
		mock_response = mock( "404 http response", :null_object => true )
		mock_response.should_receive( :is_a? ).with( Net::HTTPOK ).and_return( false )
		mock_response.should_receive( :code ).and_return( '404' )
		mock_response.should_receive( :message ).and_return( 'NOT FOUND' )
		lambda {
			ThingFish::Resource.from_http_response( mock_response )
		}.should raise_error( ArgumentError, %r{404 NOT FOUND} )
	end
	
	
	it "can export to an IO object" do
		outputIO = StringIO.new
		resource = ThingFish::Resource.new( @io )
		
		resource.export( outputIO )
		outputIO.string.should == TEST_CONTENT
	end
	
end


describe ThingFish::Resource, " created manually" do
	before( :each ) do
		@io = StringIO.new( TEST_CONTENT )
		@resource = ThingFish::Resource.new( @io )
	end
	
	
	it "raises an exception if you try to save it (no client set)" do
		lambda { @resource.save }.should raise_error( RuntimeError, /no client set/ )
	end
	
end

describe ThingFish::Resource, " created via a server fetch" do
	before( :each ) do
		@mock_client = mock( "client object", :null_object => true )
		@io = StringIO.new( TEST_CONTENT )
		@resource = ThingFish::Resource.new( @io )
		@resource.client = @mock_client
	end
	
	
	it "should store the resource via the associated client object" do
		@mock_client.should_receive( :store ).with( @resource )
		@resource.save
	end
	
end

# vim: set nosta noet ts=4 sw=4:
