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
	require 'spec/lib/handler_behavior'
	require 'time'

	require 'thingfish'
	require 'thingfish/handler/default'
	require 'thingfish/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants
include ThingFish::TestConstants
include ThingFish::TestHelpers


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::DefaultHandler do

	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
	
	before(:each) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'var/www'
		@handler          = ThingFish::DefaultHandler.new( 'resource_dir' => resdir )
		@listener         = mock( "thingfish daemon", :null_object => true )
		@filestore        = mock( "thingfish filestore", :null_object => true )
		@metastore        = mock( "thingfish metastore", :null_object => true )

		@mockmetadata 	  = mock( "metadata proxy", :null_object => true )
		@metastore.stub!( :[] ).and_return( @mockmetadata )
		@mockmetadata.stub!( :modified ).and_return('Wed Aug 29 21:24:09 -0700 2007')

		@listener.stub!( :filestore ).and_return( @filestore )
		@listener.stub!( :metastore ).and_return( @metastore )
		@handler.listener = @listener

		@request          = mock( "request", :null_object => true )
		@request_headers  = mock( "request headers", :null_object => true )
		@response         = mock( "response", :null_object => true )
		@response_headers = mock( "response headers", :null_object => true )

		@request.stub!( :headers ).and_return( @request_headers )
		@response.stub!( :headers ).and_return( @response_headers )
		@request.stub!( :has_multipart_body? ).and_return( false )
	end


	### Shared behaviors
	# it_should_behave_like "A Handler"


	### Index requests

	it "handles GET / with HTML when HTML is accepted" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		@request.should_receive( :accepts? ).with( 'text/html' ).and_return( true )
		
		@response.should_receive( :body= ).with( /<html/i )
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		
		@handler.handle_get_request( @request, @response )
	end

	it "handles GET / with an array of handler metadata when HTML is not accepted" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		@request.should_receive( :accepts? ).with( 'text/html' ).and_return( false )
		
		@response.should_receive( :body= ).with( anything() )
		@response_headers.should_not_receive( :[]= ).with( :content_type, anything() )
		
		@handler.handle_get_request( @request, @response )
	end


	it "does not modify the response on unknown URIs" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/pork' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		
		@response.should_not_receive( :body= )
		@response_headers.should_not_receive( :[]= ).with( :content_type=, anything() )

		@handler.handle_get_request( @request, @response )
	end

	it "handles POST /" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		body = StringIO.new( TEST_CONTENT )
		metadata = stub( "metadata hash" )

		@request.should_receive( :get_body_and_metadata ).and_return([ body, metadata ])

		@response_headers.should_receive( :[]= ).
			with( :location, %r{/#{TEST_UUID}} )
		@response.should_receive( :body= ).
			once.with( /Uploaded with ID #{TEST_UUID}/ )
		@response.should_receive( :status= ).
			once.with( HTTP::CREATED )

		@listener.should_receive( :store_resource ).
			with( body, metadata ).
			and_return( TEST_UUID )

		@handler.handle_post_request( @request, @response )
	end


	it "raises a ThingFish::RequestEntityTooLargeError for an upload to / that exceeds quota" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		body = StringIO.new( TEST_CONTENT )
		md = stub( "metadata hash" )
		
		@request.should_receive( :get_body_and_metadata ).and_return([ body, md ])
		@listener.should_receive( :store_resource ).
			with( body, md ).
			and_return { raise ThingFish::FileStoreQuotaError, "too NARROW, sucka!" }

		lambda {
			@handler.handle_post_request( @request, @response )
		}.should raise_error( ThingFish::RequestEntityTooLargeError, /too NARROW/ )
	end


	it "sends a METHOD_NOT_ALLOWED response for PUT to /" do
		uri = URI.parse( "http://thingfish.laika.com:3474/" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'GET, HEAD, POST' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		@handler.handle_put_request( @request, @response )
	end
	

	it "sends a METHOD_NOT_ALLOWED response for DELETE to /" do
		uri = URI.parse( "http://thingfish.laika.com:3474/" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'GET, HEAD, POST' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		@handler.handle_delete_request( @request, @response )
	end
	

	

	### GET/HEAD /«UUID» request tests
	
	it "handles HEAD /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		etag = %q{"%s"} % [ TEST_CHECKSUM ]

		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )

		@response.should_receive( :status= ).with( HTTP::OK )

		@request.should_receive( :http_method ).and_return( 'HEAD' )
		@request.should_receive( :is_cached_by_client? ).at_least(:once).and_return( false )
		@response.should_not_receive( :body= )
		@response_headers.should_receive( :[]= ).with( :etag, etag )
		@response_headers.should_receive( :[]= ).with( :expires, an_instance_of(String) )
		@response_headers.should_receive( :[]= ).with( :content_length, 1024 )

		@filestore.should_receive( :size ).and_return( 1024 )

		@mockmetadata.should_receive( :checksum ).
			at_least(:once).and_return( TEST_CHECKSUM )

		@handler.handle_head_request( @request, @response )
	end
	
	
	it "normalizes the case of UUIDs" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ.to_s.upcase}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@request_headers.stub!( :[] ).and_return( nil )
		@request.stub!( :http_method ).and_return( "HEAD" )
		@handler.handle_head_request( @request, @response )
	end


	it "handles GET /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		
		etag = %{"%s"} % [TEST_CHECKSUM]

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@request.should_receive( :is_cached_by_client? ).
			at_least( :once ).
			and_return( false )
		@response.should_receive( :status= ).with( HTTP::OK )

		@mockmetadata.should_receive( :checksum ).
			at_least(:once).
			and_return( TEST_CHECKSUM )
		@request_headers.stub!( :[] ).and_return( nil )
		
		@filestore.should_receive( :fetch_io ).
			with( TEST_UUID_OBJ ).
			and_return( :an_io )
		@filestore.should_receive( :size ).and_return( 1024 )

		@response_headers.should_receive( :[]= ).with( :etag, etag )
		@response_headers.should_receive( :[]= ).
			with( :expires, an_instance_of(String) )
		@response_headers.should_receive( :[]= ).
			with( :content_length, 1024 )

		@response.should_receive( :body= ).with( :an_io )

		@request.stub!( :http_method ).and_return( 'GET' )
		@handler.handle_get_request( @request, @response )
	end


	it "doesn't set the content disposition header by default" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).
			at_least( :once ).
			and_return( uri )

		@request.should_receive( :is_cached_by_client? ).
			at_least( :once ).
			and_return( false )

		query_args = mock( "uri query arguments", :null_object => true )
		@request.stub!( :query_args ).and_return( query_args )
		query_args.should_receive( :has_key? ).with( 'attach' ).and_return( false )

		@response_headers.
			should_not_receive( :[]= ).
			with( :content_disposition, anything() )

		@request.stub!( :http_method ).and_return( 'GET' )
		@handler.handle_get_request( @request, @response )
	end


	it "sets the content disposition of the requested resource if asked to do so" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).
			at_least( :once ).
			and_return( uri )

		@request.should_receive( :is_cached_by_client? ).
			at_least( :once ).
			and_return( false )

		query_args = mock( "uri query arguments", :null_object => true )
		@request.stub!( :query_args ).and_return( query_args )
		query_args.should_receive( :has_key? ).with( 'attach' ).and_return( true )
	
		@mockmetadata.stub!( :title ).and_return('potap.mp3')

		@response_headers.
			should_receive( :[]= ).
			with( :content_disposition,
				'attachment; ' +
				'filename="potap.mp3"; ' + 
				'modification-date="Wed, 29 Aug 2007 21:24:09 -0700"' )

		@request.stub!( :http_method ).and_return( 'GET' )
		@handler.handle_get_request( @request, @response )
	end


	it "responds with a 404 NOT FOUND for a GET to a nonexistent /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :body= ).with( /not found/i )

		@handler.handle_get_request( @request, @response )
	end


	it "sends a METHOD_NOT_ALLOWED response for POST to /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'DELETE, GET, HEAD, PUT' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		@request.stub!( :http_method ).and_return( 'POST' )
		@handler.handle_post_request( @request, @response )
	end
	

	### Caching tests
	
	it "checks the request to see if it can return a 304 NOT MODIFIED response" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		modtime = 8.days.ago
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		etag = %q{"%s"} % [TEST_CHECKSUM]

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		
		@mockmetadata.should_receive( :modified ).
			at_least( 1 ).
			and_return( modtime )
		@mockmetadata.should_receive( :checksum ).
			at_least( 1 ).
			and_return( TEST_CHECKSUM )

		@request.should_receive( :is_cached_by_client? ).
			with( TEST_CHECKSUM, modtime ).
			and_return( true )
		
		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
		@response_headers.should_receive( :[]= ).
			with( :etag, etag )

		@handler.handle_get_request( @request, @response )
	end
	

	### PUT /«uuid» tests

	it "handles PUT to /{uuid} for existing resource" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		io = StringIO.new( TEST_CONTENT )
		metadata = stub( "metadata hash" )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@request.should_receive( :get_body_and_metadata ).once.and_return([ io, {} ])
		@listener.should_receive( :store_resource ).
			with( io, an_instance_of(Hash), TEST_UUID_OBJ ).
			and_return( TEST_CHECKSUM )
			
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_put_request( @request, @response )
	end


	it "handles PUT to /{uuid} for new resource" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		io = StringIO.new( TEST_CONTENT )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@request.should_receive( :get_body_and_metadata ).and_return([ io, {} ])
		@listener.should_receive( :store_resource ).
			with( io, an_instance_of(Hash), TEST_UUID_OBJ ).
			and_return( TEST_CHECKSUM )
			
		@response.should_receive( :status= ).with( HTTP::CREATED )
		@response_headers.should_receive( :[]= ).
			with( :location, /#{TEST_UUID}/i )

		@handler.handle_put_request( @request, @response )
	end

	it "raises a ThingFish::RequestEntityTooLargeError for a PUT to /{uuid} that exceeds quota" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		body = StringIO.new( "~~~" * 1024 )
		md = stub( "metadata hash" )

		@request.should_receive( :get_body_and_metadata ).and_return([ body, md ])
		@listener.should_receive( :store_resource ).
			with( body, md, TEST_UUID_OBJ ).
			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }

		lambda {
			@handler.handle_put_request( @request, @response )
		}.should raise_error( ThingFish::RequestEntityTooLargeError, /too large/ )
	end



	### DELETE /«UUID» tests

	it "handles DELETE of /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@metastore.should_receive( :delete_properties ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_delete_request( @request, @response )
	end


	it "returns a NOT_FOUND for a DELETE of nonexistent /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :body= ).with( /not found/i )

		@handler.handle_delete_request( @request, @response )
	end

end

