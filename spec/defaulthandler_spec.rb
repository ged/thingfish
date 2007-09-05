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
	end


	### Shared behaviors
	it_should_behave_like "A Handler"


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
		@request_headers.should_receive( :[] ).
			with( :content_type ).
			and_return( TEST_CONTENT_TYPE )

		body = StringIO.new( TEST_CONTENT )

		@request.should_receive( :body ).and_return( body )
		@filestore.should_receive( :store_io ).
			once.with( an_instance_of(UUID), body ).
			and_return( TEST_CHECKSUM )

		@response_headers.should_receive( :[]= ).
			with( :location, %r{/#{Patterns::UUID_REGEXP}} )
		@response.should_receive( :body= ).
			once.with( /Uploaded with ID #{Patterns::UUID_REGEXP}/ )
		@response.should_receive( :status= ).
			once.with( HTTP::CREATED )

		mdproxy = mock( "metadata proxy", :null_object => true )
		
		@metastore.should_receive( :extract_default_metadata )
		@metastore.should_receive( :[] ).
			with( an_instance_of(UUID) ).
			at_least( 1 ).
			and_return( mdproxy )
		mdproxy.should_receive( :checksum= ).with( TEST_CHECKSUM )

		@handler.handle_post_request( @request, @response )
	end


	it "returns a 413 REQUEST ENTITY TOO LARGE for an upload to / that exceeds quota" do
		uri = URI.parse( 'http://thingfish.laika.com:3474/' )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		body = StringIO.new( TEST_CONTENT )
		
		@request.should_receive( :body ).and_return( body )			
		@filestore.should_receive( :store_io ).
			with( an_instance_of(UUID), body ).
			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }

		@metastore.should_receive( :delete_properties ).with( an_instance_of(UUID) )

		@response.should_receive( :status= ).with( HTTP::REQUEST_ENTITY_TOO_LARGE )
		@response.should_receive( :body= ).with( /too large, sucka!/ )

		Time.stub!( :parse ).and_return( @time )
		@handler.handle_post_request( @request, @response )
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
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		@request_headers.should_receive( :[] ).
			with( :if_modified_since ).
			at_least( :once ).
			and_return( nil )
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			at_least( :once ).
			and_return( nil )

		etag = %q{"%s"} % [ TEST_CHECKSUM ]

		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )

		@response.should_receive( :status= ).with( HTTP::OK )

		@request.should_receive( :http_method ).and_return( 'HEAD' )
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
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		
		etag = %{"%s"} % [TEST_CHECKSUM]

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
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


	it "sets the content disposition of the requested resource" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).
			at_least( :once ).
			and_return( uri )

		@query_args = mock( "uri query arguments", :null_object => true )
		@request.stub!( :query_args ).and_return( @query_args )
		@query_args.should_receive( :[] ).with( 'attach' ).and_return( false )
	
		@mockmetadata.stub!( :title ).and_return('potap.mp3')
		@request_headers.
			should_receive( :[] ).
			with( :if_modified_since ).
			and_return( nil )
		@request_headers.
			should_receive( :[] ).
			with( :if_none_match ).
			and_return( nil )

		@response_headers.
			should_receive( :[]= ).
			with( :content_disposition,
				'filename=potap.mp3; ' + 
				'modification-date="Wed, 29 Aug 2007 21:24:09 -0700"' )

		@request.stub!( :http_method ).and_return( 'GET' )
		@handler.handle_get_request( @request, @response )
	end


	it "responds with a 404 NOT FOUND for a GET to a nonexistent /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :body= ).with( /not found/i )

		@handler.handle_get_request( @request, @response )
	end


	it "sends a METHOD_NOT_ALLOWED response for POST to /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
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
	
	# [RFC 2616]: If any of the entity tags match the entity tag of the
	# entity that would have been returned in the response to a similar
	# GET request (without the If-None-Match header) on that resource,
	# or if "*" is given and any current entity exists for that resource,
	# then the server MUST NOT perform the requested method, unless
	# required to do so because the resource's modification date fails
	# to match that supplied in an If-Modified-Since header field in the
	# request.

	it "checks request's 'If-Modified-Since' header to see if it can " +
		"return a 304 NOT MODIFIED response" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@request_headers.should_receive( :[] ).
			with( :if_modified_since ).
			and_return( 2.days.ago.httpdate )

		etag = %q{"%s"} % [TEST_CHECKSUM]

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		
		@mockmetadata.should_receive( :modified ).
			at_least( 1 ).
			and_return( 8.days.ago.to_s )
		@mockmetadata.should_receive( :checksum ).
			at_least( 1 ).
			and_return( TEST_CHECKSUM )
		
		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
		@response_headers.should_receive( :[]= ).
			with( :etag, etag )

		@handler.handle_get_request( @request, @response )
	end
	

	it "checks request's single cache token to see if it can return a " +
		"304 NOT MODIFIED response" do

		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		etag = %q{"%s"} % 'd6af7eeb992c81ba7b3b0fac3693d7fd'

		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( etag )

		@mockmetadata.should_receive( :checksum ).
			at_least(:twice).and_return( etag )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@response.should_receive( :status= ).
			with( HTTP::NOT_MODIFIED )

		@handler.handle_get_request( @request, @response )
	end
	

	it "checks all of request's cache tokens to see if it can return " +
		"a 304 NOT MODIFIED response" do

		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		etag = %q{"%s"} % 'd6af7eeb992c81ba7b3b0fac3693d7fd'

		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( %Q{W/"v1.2", "#{etag}"} )

		@mockmetadata.should_receive( :checksum ).
			at_least(:twice).and_return( etag )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )

		@handler.handle_get_request( @request, @response )
	end
	

	it "ignores weak cache tokens" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		etag = 'W/"v1.2"'

		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( etag )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_get_request( @request, @response )
	end


	it "returns a 304 NOT MODIFIED for a GET with a wildcard If-None-Match" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( '*' )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )

		@handler.handle_get_request( @request, @response )
	end


	it "ignores a wildcard 'If-None-Match' if the 'If-Modified-Since' " +
		"header is out of date" do

		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )
		etag = %q{"%s"} % [ TEST_CHECKSUM ]

		# If the resource exists
		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
 
		metastore = mock( "metastore", :null_object => true )
		mdproxy   = mock( "metadata proxy", :null_object => true )
		listener  = mock( "thingfish daemon", :null_object => true )
		metastore.stub!( :[] ).and_return( mdproxy )
		listener.stub!( :filestore ).and_return( @filestore )
		listener.stub!( :metastore ).and_return( metastore )
		@handler.listener = listener
 
		# Check cacheability, which should indicate it's not cacheable
		@request_headers.should_receive( :[] ).
			with( :if_modified_since ).
			and_return( 8.days.ago.httpdate )
		mdproxy.should_receive( :modified ).
			at_least( :once ).
			and_return( 2.days.ago.to_s )
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( '*' )
		mdproxy.should_receive( :checksum ).
			at_least( :once ).and_return( TEST_CHECKSUM )
  
		# ...so it should fetch the resource's IO
		@filestore.should_receive( :fetch_io ).
			with( TEST_UUID_OBJ ).
			and_return( :an_io )
		@filestore.should_receive( :size ).and_return( 1024 )
  
		# ...and respond with it
		@response_headers.should_receive( :[]= ).with( :etag, etag )
		@response_headers.should_receive( :[]= ).
			with( :expires, an_instance_of(String) )
		@response_headers.should_receive( :[]= ).
			with( :content_length, 1024 )
  
		@response.should_receive( :body= ).with( :an_io )
  
		@request.stub!( :http_method ).and_return( 'GET' )
		@handler.handle_get_request( @request, @response )
	end


	### PUT /«uuid» tests

	it "handles PUT to /{uuid} for existing resource" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@request_headers.should_receive( :[] ).
			with( :content_type ).
			and_return( TEST_CONTENT_TYPE )

		io = StringIO.new( TEST_CONTENT )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@request.should_receive( :body ).and_return( io )
		@filestore.should_receive( :store_io ).
			with( TEST_UUID_OBJ, io ).
			and_return( TEST_CHECKSUM )
 		@metastore.
			should_receive( :extract_default_metadata ).
			with( TEST_UUID_OBJ, @request )
		@mockmetadata.should_receive( :checksum= ).with( TEST_CHECKSUM )
			
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_put_request( @request, @response )
	end


	it "handles PUT to /{uuid} for new resource" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@request_headers.should_receive( :[] ).
			with( :content_type ).
			and_return( TEST_CONTENT_TYPE )

		io = StringIO.new( TEST_CONTENT )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@request.should_receive( :body ).and_return( io )
		@filestore.should_receive( :store_io ).
			with( TEST_UUID_OBJ, io ).
			and_return( TEST_CHECKSUM )
		@metastore.
			should_receive( :extract_default_metadata ).
			with( TEST_UUID_OBJ, @request )

		@mockmetadata.should_receive( :checksum= ).with( TEST_CHECKSUM )

		@response.should_receive( :status= ).with( HTTP::CREATED )
		@response_headers.should_receive( :[]= ).
			with( :location, /#{TEST_UUID}/i )

		@handler.handle_put_request( @request, @response )
	end

	it "returns a 413 REQUEST ENTITY TOO LARGE for a PUT to /{uuid} that exceeds quota" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		body = StringIO.new( "~~~" * 1024 )

		@request.should_receive( :body ).and_return( body )
		@filestore.should_receive( :store_io ).with( TEST_UUID_OBJ, body ).
			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }
		@response.should_receive( :status= ).
			with( HTTP::REQUEST_ENTITY_TOO_LARGE )
		@response.should_receive( :body= ).with( /too large/i )

		@handler.handle_put_request( @request, @response )
	end



	### DELETE /«UUID» tests

	it "handles DELETE of /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_delete_request( @request, @response )
	end


	it "returns a NOT_FOUND for a DELETE of nonexistent /{uuid}" do
		uri = URI.parse( "http://thingfish.laika.com:3474/#{TEST_UUID_OBJ}" )
		@request.should_receive( :uri ).at_least( :once ).and_return( uri )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :body= ).with( /not found/i )

		@handler.handle_delete_request( @request, @response )
	end

end

