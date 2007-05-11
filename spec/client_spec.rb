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
	require 'thingfish/client'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Client do
	include ThingFish::TestConstants
	include ThingFish::Constants
	
	before(:each) do
		@mock_response = mock( "response", :null_object => true )
		@mock_conn = mock( "HTTP connection", :null_object => true )

		Net::HTTP.stub!( :start ).and_yield( @mock_conn )

		@client = ThingFish::Client.new( TEST_SERVER )
	end


	it "fetches a resource from the server by UUID via HTTP" do
		@mock_response
		@client.fetch( TEST_UUID ) do |res|
			
		end
	end
	
	
	
	it "stores a resource by uploading it to the server" do
		resource = ThingFish::Resource.new( TEST_CONTENT, :format => 'gel/pudding' )
		mock_request = mock( "request object", :null_object => true )
		
		Net::HTTP::Post.should_receive( :new ).with( '/' ).and_return( mock_request )
		mock_request.should_receive( :method ).and_return( "POST" )

		@mock_conn.should_receive( :request ).with( mock_request ).and_return( @mock_response )
		@mock_response.should_receive( :code ).and_return( HTTP::CREATED )
		@mock_response.should_receive( :[] ).with( 'Location' ).and_return( '/' + TEST_UUID )
		
		rval = @client.store( resource )
		rval.should be_an_instance_of( ThingFish::Resource )
		resource.uuid.should == TEST_UUID
	end
	

	it "updates a resource by uploading it to the server" do
		resource = ThingFish::Resource.new( TEST_CONTENT, :format => 'gel/pudding' )
		resource.uuid = TEST_UUID

		mock_request = mock( "request object", :null_object => true )
		
		Net::HTTP::Put.should_receive( :new ).with( "/#{TEST_UUID}" ).and_return( mock_request )
		mock_request.should_receive( :method ).and_return( "PUT" )

		@mock_conn.should_receive( :request ).with( mock_request ).and_return( @mock_response )
		@mock_response.should_receive( :code ).and_return( HTTP::OK )
		@mock_response.should_receive( :[] ).with( 'Location' ).and_return( '/' + TEST_UUID )
		
		rval = @client.store( resource )
		rval.should be_an_instance_of( ThingFish::Resource )
		resource.uuid.should == TEST_UUID
	end
	

	#   
	#   # Or do it all in one line
	#   resource = client.store( File.open("mahlonblob.dxf"), :format => 'image/x-dxf' )
	#   # =>  #<ThingFish::Resource:0xa5a5be UUID:7602813e-dc77-11db-837f-0017f2004c5e>
	#   
	#   # Set some more metadata (method style):
	#   resource.owner = 'mahlon'
	#   resource.description = "3D model used to test the new All Open Source pipeline"
	#   # ...or hash style:
	#   resource[:keywords] = "3d, model, mahlon"
	#   resource[:date_created] = Date.today
	#
	#   # Now save the resource back to the server it was fetched from
	#   resource.save
	#
	#	# Discard changes in favor of server side data
	#	resource.revert!
	#
	#
	#   ### Fetching
	#   
	#   # Fetch a resource by UUID
	#   uuid = '7602813e-dc77-11db-837f-0017f2004c5e'
	#   resource = client.fetch( uuid )
	#   # =>  #<ThingFish::Resource:0xa5a5be UUID:7602813e-dc77-11db-837f-0017f2004c5e>
	#   
	#   # Fetch a GIF resource as a PNG if the server supports that transformation:
	#   resource = client.fetch( uuid, :accept => ['image/png'] )
	#
	#   # Fetch a TIFF resource as either a JPEG or a PNG, preferring the former:
	#   resource = client.fetch( uuid, :accept => ['image/jpeg', 'image/png;q=0.5'] )
	#
	#   # Now load the resource's data from the server
	#   resource.load     # => true
	#
	#   # ...or just access it which will load it the first time it's needed
	#   resource.data     # => "(DXF data)"
	#
	#   # Fetch a resource object and load its data immediately instead of when it's
	#   # first used
	#   resource = client.fetch( uuid, :preload => true )
	#
	#   # Check to see if a UUID is a valid resource
	#   client.has?( uuid ) # => true
	#
	#
	#   ### Searching
	# 
	#   # ...or search for resources whose metadata match search criteria. Find
	#   # all DXF objects owned by Mahlon:
	#   resources = client.find( :format => 'image/x-dxf',
	#                            :owner => 'mahlon'  )
	#   # =>  [ #<ThingFish::Resource:0xa5a5be UUID:7602813e-dc77-11db-837f-0017f2004c5e>,
	#           #<ThingFish::Resource:0xade481 UUID:bb017a4e-fb92-49dc-8327-9c219d6c81ba> ]
	#
	#
	#   ### Streaming data
	#
	#   # Fetch the data for the resource from the server and write it to a
	#   # file:
	#   resource.export_to_file( "mahlonthing.dxf" )
	#
	#	# Export to an IO object for buffered write
	#	resource.export( socket )
	
end


describe ThingFish::Client, " created with no arguments" do
	include ThingFish::Constants
	
	before(:each) do
		@client = ThingFish::Client.new
	end

	
	it "will connect to localhost" do
	    @client.host.should == 'localhost'
	end

	it "will connect to the default port" do
	    @client.port.should == ThingFish::Constants::DEFAULT_PORT
	end

	it "knows what URI it's connecting to" do
	    @client.uri.should == 
			URI.parse( "http://localhost:#{ThingFish::Constants::DEFAULT_PORT}/" )
	end

	it "can connect with a username" do
		@client.user = TEST_USERNAME
		@client.user.should == TEST_USERNAME
	end

	it "can connect with a password" do
		@client.user = TEST_USERNAME
		@client.password = TEST_PASSWORD
		@client.password.should == TEST_PASSWORD
	end

end

describe ThingFish::Client, " created with a hostname" do
	include ThingFish::Constants
	
	before(:each) do
	    @client = ThingFish::Client.new( TEST_SERVER )
	end
	
	
	it "uses the default port" do
	    @client.port.should == ThingFish::Constants::DEFAULT_PORT
	end

	it "knows what URI it's connecting to" do
	    @client.uri.should == 
			URI.parse( "http://#{TEST_SERVER}:#{ThingFish::Constants::DEFAULT_PORT}/" )
	end
end


describe ThingFish::Client, " created with a uri string" do
	before(:each) do
		@uri = URI.parse( TEST_SERVER_URI )
		@client = ThingFish::Client.new( TEST_SERVER_URI )
	end


	it "uses the URI's port" do
	    @client.port.should == @uri.port
	end
end


describe ThingFish::Client, " created with a URI object" do
	before(:each) do
		@uri = URI.parse( TEST_SERVER_URI )
		@client = ThingFish::Client.new( @uri )
	end


	it "uses the URI's port" do
	    @client.port.should == @uri.port
	end
end


describe ThingFish::Client, " created with an options hash" do
	before(:each) do
		@client = ThingFish::Client.new 'thingfish.laika.com',
			:port => 5000,
			:user => TEST_USERNAME,
			:password => TEST_PASSWORD
	end
	
	it "should set the values in the options hash" do
	    @client.port.should == 5000
		@client.user.should == TEST_USERNAME
		@client.password.should == TEST_PASSWORD
	end

	
end

describe ThingFish::Client, " (class)" do

	it "raises an exception when instantiated with a bogus argument" do
		lambda { ThingFish::Client.new('asdfuh%$$$') }.
			should raise_error( URI::InvalidURIError, /asdfuh/ )
	end
    
end


# vim: set nosta noet ts=4 sw=4:
