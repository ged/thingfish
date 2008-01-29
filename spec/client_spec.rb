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

	TEST_DATASTRUCTURE = { :some => 'marshalled', :data => 'in', :a => 'Hash' }
	TEST_MARSHALLED_DATASTRUCTURE = Marshal.dump( TEST_DATASTRUCTURE )


	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	it "raises an exception when instantiated with a bogus argument" do
		lambda { ThingFish::Client.new('asdfuh%$$$') }.
			should raise_error( URI::InvalidURIError, /asdfuh/ )
	end

	it "uses the URI's port when created with a uri string" do
		@uri = URI.parse( TEST_SERVER_URI )
		@client = ThingFish::Client.new( TEST_SERVER_URI )
	    @client.port.should == @uri.port
	end

	it "uses '/' as the path when created with a pathless uri" do
		@uri = URI.parse( "http://thingfish.example.com:3474" )
		@client = ThingFish::Client.new( "http://thingfish.example.com:3474" )
		@client.uri.path.should == '/'
	end

	it "uses the URI's port when created with a URI object" do
		uri = URI.parse( TEST_SERVER_URI )
		client = ThingFish::Client.new( uri )
	    client.port.should == uri.port
	end

	it "should set the values in the options hash created with an options hash" do
		client = ThingFish::Client.new 'thingfish.laika.com',
		   :port => 5000,
		   :user => TEST_USERNAME,
		   :password => TEST_PASSWORD
        
	    client.port.should == 5000
		client.user.should == TEST_USERNAME
		client.password.should == TEST_PASSWORD
	end


	describe " created with no arguments" do
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


	describe " created with a hostname" do
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


	describe " interacts with the server via its REST interface" do
		before(:each) do
			@mock_response = mock( "response object", :null_object => true )
			@mock_request = mock( "request object", :null_object => true )
			@mock_conn = mock( "HTTP connection", :null_object => true )

			Net::HTTP.stub!( :start ).and_yield( @mock_conn ).and_return( @mock_response )

			@client = ThingFish::Client.new( TEST_SERVER )
		end


		# 
		# GET
		# 

		### GET /
		it "fetches a Hash of server information via HTTP when asked for server info" do
			Net::HTTP::Get.should_receive( :new ).
				with( '/' ).
				and_return( @mock_request )
			@mock_request.should_receive( :method ).and_return( "GET" )

			@mock_conn.should_receive( :request ).
				with( @mock_request ).
				and_return( @mock_response )
			@mock_response.should_receive( :body ).and_return( TEST_MARSHALLED_DATASTRUCTURE )

			@client.server_info.should == TEST_DATASTRUCTURE
		end
		

		### GET /{uuid}
		it "fetches a resource from the server by UUID via HTTP" do
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
	
	
		### HEAD /{uuid}
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
	
	
		### POST /
		it "converts a non-resource to a ThingFish::Resource before uploading"
		it ""
		
		it "stores a new resource by uploading it to the server via HTTP POST" do

			# Branch: conversion to resource object
			resource = mock( "Mock Resource" )
			resource.should_receive( :is_a? ).
				with( ThingFish::Resource ).
				any_number_of_times.
				and_return( true )
			resource.should_receive( :uuid ).
				and_return( nil )

			Net::HTTP::Post.should_receive( :new ).
				with( '/' ).
				and_return( @mock_request )
			@mock_request.stub!( :method ).and_return( "POST" )

			resource.should_receive( :io ).
				at_least( :once ).
				and_return( :an_io_object )
			@mock_request.should_receive( :body_stream= ).
				at_least( :once ).
			 	with( :an_io_object )
			
			# Branch: no extent
			resource.should_receive( :extent ).
				at_least( :once ).
				and_return( :number_of_bytes )
			@mock_request.should_receive( :[]= ).
			 	with( /content-length/i, :number_of_bytes )
			
			# Branch: no mimetype
			resource.should_receive( :format ).
				at_least( :once ).
				and_return( :a_mimetype )
			@mock_request.should_receive( :[]= ).
			 	with( /content-type/i, :a_mimetype )
			
			# Branch: no title
			resource.should_receive( :title ).
				at_least( :once ).
				and_return( 'a title' )
			@mock_request.should_receive( :[]= ).
			 	with( /content-disposition/i, /attachment;filename="a title"/i )
		
			@mock_conn.should_receive( :request ).
				with( @mock_request ).
				and_yield( @mock_response )
		
			@client.store( resource ).should == resource
		end
	

		### PUT /{uuid}
		it "updates a resource by uploading it to the server" do
			# Branch: conversion to resource object
			resource = mock( "Mock Resource" )
			resource.should_receive( :is_a? ).
				with( ThingFish::Resource ).
				any_number_of_times().
				and_return( true )
			resource.should_receive( :uuid ).
				and_return( TEST_UUID )

			Net::HTTP::Put.should_receive( :new ).
				with( '/' + TEST_UUID ).
				and_return( @mock_request )
			@mock_request.should_receive( :method ).and_return( "POST" )

			resource.should_receive( :io ).
				at_least( :once ).
				and_return( :an_io_object )
			@mock_request.should_receive( :body_stream= ).
				at_least( :once ).
			 	with( :an_io_object )

			# Branch: no extent
			resource.should_receive( :extent ).
				at_least( :once ).
				and_return( :number_of_bytes )
			@mock_request.should_receive( :[]= ).
			 	with( /content-length/i, :number_of_bytes )
			
			# Branch: no mimetype
			resource.should_receive( :format ).
				at_least( :once ).
				and_return( :a_mimetype )
			@mock_request.should_receive( :[]= ).
			 	with( /content-type/i, :a_mimetype )
			
			# Branch: no title
			resource.should_receive( :title ).
				at_least( :once ).
				and_return( 'a title' )
			@mock_request.should_receive( :[]= ).
			 	with( /content-disposition/i, /attachment;filename="a title"/i )
		
			@mock_conn.should_receive( :request ).
				with( @mock_request ).
				and_yield( @mock_response )
		
			@client.store( resource ).should == resource
		end


	end # REST API

end

# vim: set nosta noet ts=4 sw=4:
