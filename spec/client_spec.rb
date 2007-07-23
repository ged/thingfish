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
	require 'thingfish/constants'
	require 'thingfish/client'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestConstants
include ThingFish::Constants

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Client do
	
	before(:each) do
		@mock_response = mock( "response object", :null_object => true )
		@mock_request = mock( "request object", :null_object => true )
		@mock_conn = mock( "HTTP connection", :null_object => true )

		Net::HTTP.stub!( :start ).and_yield( @mock_conn )

		@client = ThingFish::Client.new( TEST_SERVER )
	end


	it "fetches a resource from the server by UUID via HTTP" do
		# ThingFish.logger = Logger.new( $stderr )
		# ThingFish.logger.level = Logger::DEBUG

		Net::HTTP::Get.should_receive( :new ).with( '/' + TEST_UUID ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "GET" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_yield( @mock_response )

		Net::HTTPOK.stub!( :=== ).and_return( true )

		@mock_response.should_receive( :is_a? ).with( Net::HTTPOK ).and_return( true )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
		@mock_response.should_receive( :message ).and_return( "OK" )
		
		rval = @client.fetch( TEST_UUID )
		rval.should be_an_instance_of( ThingFish::Resource )
		rval.uuid.should == TEST_UUID
		rval.client.should == @client
	end


	it "fetching a non-existant resource should return nil" do
		Net::HTTP::Get.should_receive( :new ).with( '/' + TEST_UUID ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "GET" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_yield( @mock_response )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::NOT_FOUND )
		@mock_response.should_receive( :message ).and_return( "NOT FOUND" )
		
		@client.fetch( TEST_UUID ).should be_nil
	end
	
	
	it "returns true when asked if it has a uuid that corresponds to a resource it has" do
		Net::HTTP::Head.should_receive( :new ).with( '/' + TEST_UUID ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "HEAD" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_yield( @mock_response )

		Net::HTTPOK.stub!( :=== ).and_return( true )

		@mock_response.should_receive( :is_a? ).with( Net::HTTPOK ).and_return( true )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
		@mock_response.should_receive( :message ).and_return( "OK" )
		
		@client.has?( TEST_UUID ).should be_true
	end
	
	
	it "returns false when asked if it has a uuid that corresponds to a resource it has not" do
		Net::HTTP::Head.should_receive( :new ).with( '/' + TEST_UUID ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "HEAD" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_yield( @mock_response )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::NOT_FOUND )
		@mock_response.should_receive( :message ).and_return( "NOT FOUND" )

		@client.has?( TEST_UUID ).should be_false
	end
	
	
	it "stores a resource by uploading it to the server" do
		resource = ThingFish::Resource.new( TEST_CONTENT, :format => 'gel/pudding' )
		
		Net::HTTP::Post.should_receive( :new ).with( '/' ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "POST" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_return( @mock_response )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::CREATED )
		@mock_response.should_receive( :[] ).with( 'Location' ).and_return( '/' + TEST_UUID )
		
		rval = @client.store( resource )
		rval.should be_an_instance_of( ThingFish::Resource )
		resource.uuid.should == TEST_UUID
	end
	

	it "updates a resource by uploading it to the server" do
		resource = ThingFish::Resource.new( TEST_CONTENT, :format => 'gel/pudding' )
		resource.uuid = TEST_UUID

		Net::HTTP::Put.should_receive( :new ).with( "/#{TEST_UUID}" ).and_return( @mock_request )
		@mock_request.should_receive( :method ).and_return( "PUT" )

		@mock_conn.should_receive( :request ).with( @mock_request ).and_return( @mock_response )
		@mock_response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
		
		rval = @client.store( resource )
		rval.should be_an_instance_of( ThingFish::Resource )
		resource.uuid.should == TEST_UUID
	end
	

end


describe ThingFish::Client, " created with no arguments" do
	
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


describe ThingFish::Client, " created with a pathless uri" do
	before( :each ) do
		@uri = URI.parse( "http://thingfish.example.com:3474" )
		@client = ThingFish::Client.new( "http://thingfish.example.com:3474" )
	end

	it "uses '/' as the path" do
		@client.uri.path.should == '/'
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
