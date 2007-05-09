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
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Client do
	before(:each) do
		@client = ThingFish::Client.new( TEST_SERVER )
	end

	it "fetches a resource from the server by UUID via HTTP" do
		mock_response = mock( "response", :null_object => true )
		Net::HTTP.stub!( :start ).and_return( mock_response )

		@client.fetch( TEST_UUID ) do |res|
		end
	end
	
	
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
