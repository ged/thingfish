#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'spec'
require 'spec/lib/constants'
require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/client'
require 'thingfish/resource'


include ThingFish::TestConstants
include ThingFish::Constants

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Client do
	include ThingFish::SpecHelpers

	TEST_DATASTRUCTURE = { :some => 'marshalled', :data => 'in', :a => 'Hash' }
	TEST_MARSHALLED_DATASTRUCTURE = Marshal.dump( TEST_DATASTRUCTURE )
	TEST_SERVER_INFO = {
		'version'  => '0.1.0',
		'handlers' => {
			'default'        => ['/'],
			'staticcontent'  => ['/metadata', '/', '/upload', '/search'],
			'simplemetadata' => ['/metadata'],
			'simplesearch'   => ['/search'],
			'inspect'        => ['/inspect'],
			'formupload'     => ['/upload']
		},
	}

	before( :all ) do
			setup_logging( :fatal )
	end

	after( :all ) do
		reset_logging()
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

	it "masks the URI password in inspected output" do
		client = ThingFish::Client.new( 'http://foompy:chompers@localhost:3474/' )
		client.inspect.should_not =~ /chompers/
	end


	### No args creation
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

		it "defaults to disabled profiling" do
			@client.profile.should_not == true
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


	describe " created with profiling enabled" do
		before(:each) do
			@response = mock( "response object", :null_object => true )
			@request = mock( "request object", :null_object => true )
			@conn = mock( "HTTP connection", :null_object => true )

			Net::HTTP.stub!( :start ).and_yield( @conn ).and_return( @response )

			@client = ThingFish::Client.new( TEST_SERVER, :profile => true )
			@client.instance_variable_set( :@server_info, TEST_SERVER_INFO )
		end

		it "adds a profiling query argument to the request path" do
			Net::HTTP::Head.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :HEAD )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )

			path = '/'
			@request.should_receive( :path ).at_least( :once ).and_return( path )

			@client.profile.should == true
			@client.has?( TEST_UUID ).should be_false
			path.should == '/?_profile=true'
		end


		it "adds a profiling query argument to the request path after existing arguments" do
			Net::HTTP::Head.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :HEAD )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )

			path = '/?sexydrownwatch=pamelllla'
			@request.should_receive( :path ).at_least( :once ).and_return( path )

			@client.profile.should == true
			@client.has?( TEST_UUID ).should be_false
			path.should == '/?sexydrownwatch=pamelllla&_profile=true'
		end
	end


	describe " created with valid connection information" do

		before(:each) do
			@response = mock( "response object", :null_object => true )
			@request = mock( "request object", :null_object => true )
			@conn = mock( "HTTP connection", :null_object => true )

			Net::HTTP.stub!( :start ).and_yield( @conn ).and_return( @response )

			@client = ThingFish::Client.new( TEST_SERVER )
			# Set the server info hash so it doesn't try to fetch it
			@client.instance_variable_set( :@server_info, TEST_SERVER_INFO )
		end


		it "builds uris for server endpoints based on the server info hash" do
			@client.server_uri( 'simplemetadata' ).to_s.should ==
				'http://' + TEST_SERVER + ':3474' +
				TEST_SERVER_INFO['handlers']['simplemetadata'].first
		end


		### Server info
		it "can fetch server information via HTTP" do
			# Unset the cached server info hash for this one test
			@client.instance_variable_set( :@server_info, nil )

			Net::HTTP::Get.should_receive( :new ).
				with( '/' ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( true )

			@response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
			@response.should_receive( :message ).and_return( "OK" )
			@response.should_receive( :[] ).
				with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).and_return( :serialized_server_info )

			Marshal.should_receive( :load ).
				with( :serialized_server_info ).
				and_return( :server_info )

			@client.server_info.should == :server_info
		end


		it "raises an exception if fetching #server_info responds with anything other than a 200" do
			# Unset the cached server info hash for this one test
			@client.instance_variable_set( :@server_info, nil )

			Net::HTTP::Get.should_receive( :new ).
				with( '/' ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( false )

			@response.should_receive( :error! ).once.
				and_raise( RuntimeError.new("server error") )

			lambda {
				@client.server_info
			  }.should raise_error( RuntimeError, /server error/ )
		end


		it "can fetch server information (fallback YAML filter)" do
			# Unset the cached server info hash for this one test
			@client.instance_variable_set( :@server_info, nil )

			Net::HTTP::Get.should_receive( :new ).
				with( '/' ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( true )

			# @response.should_receive( :status ).at_least(:once).and_return( HTTP::OK )
			@response.should_receive( :message ).and_return( "OK" )
			@response.should_receive( :[] ).
				with( /content-type/i ).
				and_return( 'text/x-yaml' )
			@response.should_receive( :body ).and_return( :serialized_server_info )

			YAML.should_receive( :load ).
				with( :serialized_server_info ).
				and_return( :server_info )

			@client.server_info.should == :server_info
		end


		it "caches already-fetched server info" do
			Net::HTTP::Get.should_not_receive( :new )
			@client.server_info.should == TEST_SERVER_INFO
		end


		### Fetch resource data
		it "can fetch a resource from the server by UUID (YAML response)" do
			Net::HTTP::Get.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )

			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( true )

			@response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
			@response.should_receive( :message ).and_return( "OK" )
			@response.should_receive( :[] ).
				with( /content-type/i ).
				and_return( 'text/x-yaml' )
			@response.should_receive( :body ).and_return( :serialized_metadata )

			YAML.should_receive( :load ).
				with( :serialized_metadata ).
				and_return( :some_metadata )
			ThingFish::Resource.should_receive( :new ).
				with( nil, @client, TEST_UUID, :some_metadata ).
				and_return( :a_new_resource )

			rval = @client.fetch( TEST_UUID )
			rval.should == :a_new_resource
		end


		it "returns nil when someone attempts to fetch a non-existant resource" do
			Net::HTTP::Get.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )

			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( false )
			Net::HTTPCreated.should_receive( :=== ).with( @response).and_return( false )
			Net::HTTPSuccess.should_receive( :=== ).with( @response).and_return( false )

			@response.should_receive( :code ).at_least(:once).and_return( HTTP::NOT_FOUND )
			@response.should_receive( :message ).and_return( "NOT FOUND" )

			@client.fetch( TEST_UUID ).should be_nil
		end


		### Fetch resource metadata
		it "can fetch a resource from the server by UUID (marshalled ruby response)" do
			Net::HTTP::Get.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )

			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( true )

			@response.should_receive( :code ).at_least(:once).and_return( HTTP::OK )
			@response.should_receive( :message ).and_return( "OK" )
			@response.should_receive( :[] ).
				with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).and_return( :serialized_metadata )

			Marshal.should_receive( :load ).
				with( :serialized_metadata ).
				and_return( :some_metadata )
			ThingFish::Resource.should_receive( :new ).
				with( nil, @client, TEST_UUID, :some_metadata ).
				and_return( :a_new_resource )

			rval = @client.fetch( TEST_UUID )
			rval.should == :a_new_resource
		end


		it "can fetch a resource's data from the server" do
			Net::HTTP::Get.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['default'].first + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :[]= ).with( 'Accept', '*/*' )
			@request.should_receive( :method ).and_return( :GET )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response).and_return( true )

			# Branch: in-memory vs. on disk
			pathname = mock( "pathname object" )
			filehandle = mock( "filehandle object" )

			@response.should_receive( :[] ).with( /content-length/i ).
				and_return( ThingFish::Client::MAX_INMEMORY_RESPONSE_SIZE + 100 )
			Pathname.should_receive( :new ).and_return( pathname )
			pathname.should_receive( :+ ).with( "tf-#{TEST_UUID}.data.0" ).
				and_return( pathname )

			flags = File::EXCL|File::CREAT|File::RDWR
			pathname.should_receive( :open ).with( flags, 0600 ).
				and_return( filehandle )
			pathname.should_receive( :delete )

			@response.should_receive( :read_body ).
				and_yield( :first_chunker ).
				and_yield( :second_chunker )
			filehandle.should_receive( :write ).with( :first_chunker )
			filehandle.should_receive( :write ).with( :second_chunker )
			filehandle.should_receive( :rewind )

			@client.fetch_data( TEST_UUID ).should == filehandle
		end


		### #has? predicate method
		it "returns true when asked if it has a uuid that corresponds to a resource it has" do
			Net::HTTP::Head.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :HEAD )

			@conn.should_receive( :request ).with( @request ).and_return( @response )

			@response.should_receive( :is_a? ).with( Net::HTTPSuccess ).and_return( true )

			@client.has?( TEST_UUID ).should be_true
		end


		it "returns false when asked if it has a uuid that corresponds to a resource " +
		   "the server doesn't have" do
			Net::HTTP::Head.should_receive( :new ).
				with( TEST_SERVER_INFO['handlers']['simplemetadata'].first + '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :HEAD )

			@conn.should_receive( :request ).with( @request ).and_return( @response )
			@response.should_receive( :is_a? ).with( Net::HTTPSuccess ).and_return( false )

			@client.has?( TEST_UUID ).should be_false
		end


		### Storing resource data
		it "can upload a file and return a new ThingFish::Resource object" do
			resource = mock( "resource" )

			ThingFish::Resource.should_receive( :new ).with( :a_file, @client ).
				and_return( resource )
			resource.should_receive( :uuid ).and_return( nil )

			Net::HTTP::Post.should_receive( :new ).with( '/' ).and_return( @request )
			@request.stub!( :method ).and_return( :POST )

			resource.should_receive( :io ).at_least( :once ).and_return( :an_io_object )
			resource.should_receive( :extent ).at_least( :once ).and_return( :number_of_bytes )
			resource.should_receive( :format ).at_least( :once ).and_return( :a_mimetype )
			resource.should_receive( :title ).at_least( :once ).and_return( 'a title' )

			@request.should_receive( :body_stream= ).at_least( :once ).with( :an_io_object )
			@request.should_receive( :[]= ).with( /content-length/i, :number_of_bytes )
			@request.should_receive( :[]= ).with( /content-type/i, :a_mimetype )
			@request.should_receive( :[]= ).
			 	with( /content-disposition/i, /attachment;filename="a title"/i )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response ).and_return( true )

			# Set the UUID from the response's Location header
			@response.should_receive( :[] ).with( /location/i ).
				and_return( 'http://thingfish.example.com/' + TEST_UUID )
			resource.should_receive( :uuid= ).with( TEST_UUID )

			# Merge response metadata
			response_metadata = {
				'description' => 'Bananas Goes to Military School',
				'checksum'    => 'A checksum',
			  }
			resource_metadata = {
				'description' => 'Bananas Goes To See Assemblage 23',
				'author'      => 'Bananas',
			  }
			merged_metadata = response_metadata.merge( resource_metadata )

			resource.should_receive( :metadata ).and_return( resource_metadata )
			@response.should_receive( :[] ).with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).
				and_return( Marshal.dump(response_metadata) )
			resource.should_receive( :metadata= ).with( merged_metadata )

			@client.store_data( :a_file ).should == resource
		end


		it "can upload an unstored ThingFish::Resource" do
			resource = mock( "resource" )
			resource.should_receive( :is_a? ).with( ThingFish::Resource ).and_return( true )
			resource.should_receive( :uuid ).and_return( nil )

			Net::HTTP::Post.should_receive( :new ).with( '/' ).and_return( @request )
			@request.stub!( :method ).and_return( :POST )

			resource.should_receive( :io ).at_least( :once ).and_return( :an_io_object )
			resource.should_receive( :extent ).at_least( :once ).and_return( :number_of_bytes )
			resource.should_receive( :format ).at_least( :once ).and_return( :a_mimetype )
			resource.should_receive( :title ).at_least( :once ).and_return( 'a title' )

			@request.should_receive( :body_stream= ).at_least( :once ).with( :an_io_object )
			@request.should_receive( :[]= ).with( /content-length/i, :number_of_bytes )
			@request.should_receive( :[]= ).with( /content-type/i, :a_mimetype )
			@request.should_receive( :[]= ).
			 	with( /content-disposition/i, /attachment;filename="a title"/i )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response ).and_return( true )

			# Set the UUID from the response's Location header
			@response.should_receive( :[] ).with( /location/i ).
				and_return( 'http://thingfish.example.com/' + TEST_UUID )
			resource.should_receive( :uuid= ).with( TEST_UUID )

			# Merge response metadata
			response_metadata = {
				'description' => 'Bananas Goes to Military School',
				'checksum'    => 'A checksum',
			  }
			resource_metadata = {
				'description' => 'Bananas Goes To See Assemblage 23',
				'author'      => 'Bananas',
			  }
			merged_metadata = response_metadata.merge(resource_metadata)

			resource.should_receive( :metadata ).and_return( resource_metadata )
			@response.should_receive( :[] ).with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).
				and_return( Marshal.dump(response_metadata) )
			resource.should_receive( :metadata= ).with( merged_metadata )


			@client.store_data( resource ).should == resource
		end


		it "raises an error when asked to store metadata for a resource that doesn't yet " +
		   "have a UUID" do

			resource = mock( "Mock Resource" )
			resource.should_receive( :uuid ).and_return( nil )

			lambda {
				@client.store_metadata( resource )
			}.should raise_error( ThingFish::ClientError, /unsaved resource/i )
		end


		it "can update a resource's metadata on the server" do
			resource_metadata = {
				'description' => 'Bananas Goes To See Assemblage 23',
				'author'      => 'Bananas',
				'extent'	  => 1203,
			  }

			Net::HTTP::Put.should_receive( :new ).and_return( @request )
			@request.stub!( :method ).and_return( :PUT )

			resource = mock( "Mock Resource" )
			resource.should_receive( :uuid ).and_return( TEST_UUID )
			resource.should_receive( :metadata ).and_return( resource_metadata )

			@conn.should_receive( :request ).with( @request ).
				and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response ).and_return( true )

			metadata = {
				'description' => 'Bananas Goes To See Assemblage 23',
				'author'      => 'Bananas',
				'extent'	  => 14002,
				'hump'        => 'catting',
			  }

			@response.should_receive( :[] ).with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).
				and_return( Marshal.dump(metadata) )

			resource.should_receive( :metadata= ).with( metadata )

			@client.store_metadata( resource )
		end



		### Updating
		it "can update file data if given a ThingFish::Resource that already has a UUID" do
			resource = mock( "Mock Resource" )
			resource.should_receive( :is_a? ).with( ThingFish::Resource ).any_number_of_times().
				and_return( true )
			resource.should_receive( :uuid ).and_return( TEST_UUID )

			Net::HTTP::Put.should_receive( :new ).with( '/' + TEST_UUID ).and_return( @request )
			@request.should_receive( :method ).and_return( :POST )

			# Branch: no extent
			# Branch: no mimetype
			# Branch: no title
			resource.should_receive( :io ).at_least( :once ).and_return( :an_io_object )
			resource.should_receive( :extent ).at_least( :once ).and_return( :number_of_bytes )
			resource.should_receive( :format ).at_least( :once ).and_return( :a_mimetype )
			resource.should_receive( :title ).at_least( :once ).and_return( 'a title' )

			@request.should_receive( :body_stream= ).at_least( :once ).with( :an_io_object )
			@request.should_receive( :[]= ).with( /content-length/i, :number_of_bytes )
			@request.should_receive( :[]= ).with( /content-type/i, :a_mimetype )
			@request.should_receive( :[]= ).
			 	with( /content-disposition/i, /attachment;filename="a title"/i )

			@conn.should_receive( :request ).with( @request ).and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response ).and_return( true )

			# Merge response metadata
			response_metadata = {
				'description' => 'A heartwarming tale of two hams and their adventures together',
				'lang'    => 'en-US',
			  }
			resource_metadata = {
				'description' => 'Ham salad, reimagined',
				'author'      => 'Napoleon the Chimp',
			  }
			merged_metadata = response_metadata.merge(resource_metadata)

			resource.should_receive( :metadata ).and_return( resource_metadata )
			@response.should_receive( :[] ).with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).
				and_return( Marshal.dump(response_metadata) )
			resource.should_receive( :metadata= ).with( merged_metadata )

			@client.store_data( resource ).should == resource
		end


		### Deleting
		it "can delete a resource from the server by its UUID" do
			Net::HTTP::Delete.should_receive( :new ).
				with( '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :DELETE )

			@conn.should_receive( :request ).
				with( @request ).
				and_yield( @response )

			@client.delete( TEST_UUID ).should be_true()
		end


		it "can delete a resource from the server via an object that knows what its UUID is" do
			resource = mock( "Mock Resource" )
			resource.should_receive( :respond_to? ).with( :uuid ).and_return( true )
			resource.should_receive( :uuid ).and_return( TEST_UUID )

			Net::HTTP::Delete.should_receive( :new ).with( '/' + TEST_UUID ).
				and_return( @request )
			@request.should_receive( :method ).and_return( :DELETE )

			@conn.should_receive( :request ).with( @request ).
				and_yield( @response )

			@client.delete( resource ).should be_true()
		end


		it "can find resources by their metadata attributes" do
			path_and_query = TEST_SERVER_INFO['handlers']['simplesearch'].first +
				'/format=image%2Fjpeg;title=*energylegs*?full'
			Net::HTTP::Get.should_receive( :new ).with( path_and_query ).
				and_return( @request )

			@request.should_receive( :method ).and_return( :GET )
			@request.should_receive( :[]= ).with( /accept/i, /#{RUBY_MARSHALLED_MIMETYPE}/ )
			@conn.should_receive( :request ).with( @request ).
				and_yield( @response )
			Net::HTTPOK.should_receive( :=== ).with( @response ).and_return( true )

			resources = [
				[ TEST_UUID,  { :soapy => 'finger' } ],
				[ TEST_UUID2, { :soapy => 'giants' } ],
				[ TEST_UUID3, { :soapy => 'shame'  } ]
			]

			@response.should_receive( :[] ).with( /content-type/i ).
				and_return( RUBY_MARSHALLED_MIMETYPE )
			@response.should_receive( :body ).
				and_return( Marshal.dump(resources) )

			criteria = {
				:format => 'image/jpeg',
				:title  => '*energylegs*',
			}

			results = @client.find( criteria )
			results.should be_an_instance_of( Array )
			results.should have( 3 ).members
			results.collect {|r| r.uuid }.
				should == [ TEST_UUID, TEST_UUID2, TEST_UUID3 ]
			results.collect {|r| r.metadata[:soapy] }.
				should == %w[ finger giants shame ]
		end


	end # REST API
end

# vim: set nosta noet ts=4 sw=4:
