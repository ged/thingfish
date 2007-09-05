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
	require 'thingfish/handler/metadata'
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

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::MetadataHandler do
	TESTING_KEYS = [ :some, :keys, :for, :testing ]
	STRINGIFIED_TESTING_KEYS = TESTING_KEYS.collect {|k| k.to_s }
	
	before(:each) do
		# ThingFish.logger.level = Logger::DEBUG
		ThingFish.logger.level = Logger::FATAL
		
		options = {
			:uris => ['/metadata']
		}

		@handler   = ThingFish::MetadataHandler.new( options )
		@request   = mock( "request", :null_object => true )
		@response  = mock( "response", :null_object => true )
		@headers   = mock( "headers", :null_object => true )
		@response.stub!( :headers ).and_return( @headers )
		@listener  = mock( "listener", :null_object => true )
		@metastore = mock( "metastore", :null_object => true )
		
		@listener.stub!( :metastore ).and_return( @metastore )
		@handler.listener = @listener
	end


	# Shared behaviors
	it_should_behave_like "A Handler"
	
	# Examples

	it "returns a page describing all metadata keys for a text/html GET to /metadata" do
		template = stub( "ERB template", :result => :rendered_output )

		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( true )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@response.should_receive( :body= ).with( :rendered_output )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a data-structure describing all metadata keys for a non-html GET to /metadata" do
		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@handler.should_not_receive( :get_erb_resource )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( STRINGIFIED_TESTING_KEYS )
		
		@handler.handle_get_request( @request, @response )
	end


#	it "handles POST /" do
#		params = {
#			'REQUEST_URI'    => '/',
#			"CONTENT_TYPE"   => TEST_CONTENT_TYPE,
#			'REQUEST_METHOD' => 'POST'
#		}
#		body = StringIO.new( TEST_CONTENT )
#
#		@request.should_receive( :params ).at_least(1).and_return( params )
#		@request.should_receive( :body ).and_return( body )
#		@filestore.should_receive( :store_io ).
#			once.with( an_instance_of(UUID), body ).
#			and_return( TEST_CHECKSUM )
#		@response.should_receive( :start ).
#			once.with( HTTP::CREATED, true ).
#			and_yield( @headers, @out )
#		@headers.should_receive( :[]= ).
#			with( 'Location', %r{/#{Patterns::UUID_REGEXP}} )
#		@out.should_receive( :write ).
#			once.with( /Uploaded with ID #{Patterns::UUID_REGEXP}/ )
#
#		mdproxy = mock( "metadata proxy", :null_object => true )
#		
#		@metastore.should_receive( :extract_default_metadata )
#		@metastore.should_receive( :[] ).
#			with( an_instance_of(UUID) ).
#			at_least( 1 ).
#			and_return( mdproxy )
#		mdproxy.should_receive( :checksum= ).with( TEST_CHECKSUM )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "returns a 413 REQUEST ENTITY TOO LARGE for an upload to / that exceeds quota" do
#		params = {
#			'REQUEST_URI'    => '/',
#			'REQUEST_METHOD' => 'POST'
#		}
#		body = StringIO.new( "~~~" * 1024 )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@request.should_receive( :body ).and_return( body )
#		@filestore.should_receive( :store_io ).once.
#			with( an_instance_of(UUID), body ).
#			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }
#
#		@metastore.should_receive( :delete_properties ).with( an_instance_of(UUID) )
#
#		@response.should_receive( :start ).once.
#			with( HTTP::REQUEST_ENTITY_TOO_LARGE, true ).and_yield( @headers, @out )
#		@out.should_receive( :write ).once.with( /too large, sucka!/ )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "returns a 405 METHOD NOT ALLOWED response to a request to / with a method other than GET or POST" do
#		params = {
#			'REQUEST_URI'    => '/',
#			'REQUEST_METHOD' => 'PUT'
#		}
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@response.should_receive( :start ).once.
#			with( HTTP::METHOD_NOT_ALLOWED, true ).
#			and_yield( @headers, @out )
#		@headers.should_receive( :[]= ).with( 'Allow', /(?:(GET|POST)\s*,?\s*){2}/ )
#		@out.should_receive( :write ).once.with( /not allowed/i )
#
#		@handler.process( @request, @response )
#	end
#
#
#
#	### GET/HEAD /«UUID» request tests
#	it "handles HEAD /<<uuid>>" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'HEAD'
#		  }
#		etag = %q{"%s"} % [TEST_CHECKSUM]
#		mockheaders = mock( "http response headers", :null_object => true )
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#
#		@response.should_receive( :status= ).with( HTTP::OK )
#		@response.should_receive( :header ).at_least(1).and_return( mockheaders )
#		@response.should_not_receive( :body= )
#
#		@filestore.should_receive( :size ).and_return( 1024 )
#		@response.should_receive( :send_status ).with( 1024 )
#		@response.should_receive( :finished )
#
#		@metastore.should_receive( :[] ).
#			at_least(:once).with( TEST_UUID_OBJ ).
#			and_return( mockmetadata )
#
#		mockmetadata.should_receive( :checksum ).
#			at_least(:once).and_return( TEST_CHECKSUM )
#		mockheaders.should_receive( :[]= ).with( 'ETag', etag )
#		mockheaders.should_receive( :[]= ).with( 'Expires', an_instance_of(String) )
#
#		@handler.process( @request, @response )
#	end
#	
#	
#	it "normalizes the case of UUIDs" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ.to_s.upcase}",
#			'REQUEST_METHOD' => 'HEAD'
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#
#		@response.should_receive( :status= ).with( HTTP::OK )
#		@response.should_receive( :header ).at_least(1).and_return({})
#		@response.should_not_receive( :body= )
#
#		@filestore.should_receive( :size ).and_return( 1024 )
#		@response.should_receive( :send_status ).with( 1024 )
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "handles GET /<<uuid>>" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'GET'
#		  }
#		testdata = 'this is some data for testing'
#		testbuf = testdata.dup
#		io = mock( 'io' )
#		mockheaders = mock( "http response headers", :null_object => true )
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#		etag = %{"%s"} % [TEST_CHECKSUM]
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).
#			with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :status= ).with( HTTP::OK )
#		@response.should_receive( :header ).at_least(1).and_return( mockheaders )
#
#		@metastore.should_receive( :[] ).
#			at_least(1).with( TEST_UUID_OBJ ).and_return( mockmetadata )
#
#		mockmetadata.should_receive( :checksum ).
#			at_least(:once).and_return( TEST_CHECKSUM )
#		mockheaders.should_receive( :[]= ).with( 'ETag', etag )
#		mockheaders.should_receive( :[]= ).with( 'Expires', an_instance_of(String) )
#
#		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_yield( io )
#
#		@filestore.should_receive( :size ).and_return( 1024 )
#		@response.should_receive( :send_status ).with( 1024 )
#		@response.should_receive( :send_header )
#
#		# Simulate reading testdata from a file
#		io.should_receive( :read ).twice.
#			with( an_instance_of(Fixnum), '' ).
#			and_return do |size,buf|
#				buf << testbuf.slice!( 0, testbuf.length )
#				buf.empty? ? nil : buf.length
#			end
#		@response.should_receive( :write ).with( testdata ).and_return( testdata.length )
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "responds with a 404 NOT FOUND for a GET to a nonexistent /<<uuid>>" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'GET'
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( false )
#		@response.should_receive( :start ).
#			once.with( HTTP::NOT_FOUND, true ).
#			and_yield( @headers, @out )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "returns a 405 METHOD NOT ALLOWED response to a request to /<uuid> with a " +
#	   "method other than GET, HEAD, PUT, or DELETE" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'TRACE'
#		}
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@response.should_receive( :start ).once.
#			with( HTTP::METHOD_NOT_ALLOWED, true ).
#			and_yield( @headers, @out )
#		@headers.should_receive( :[]= ).with( 'Allow', /(?:(GET|HEAD|PUT|DELETE)\s*,?\s*){2}/ )
#		@out.should_receive( :write ).once.with( /not allowed/i )
#
#		@handler.process( @request, @response )
#	end
#
#
#	### Caching tests
#	
#	# [RFC 2616]: If any of the entity tags match the entity tag of the
#	# entity that would have been returned in the response to a similar
#	# GET request (without the If-None-Match header) on that resource,
#	# or if "*" is given and any current entity exists for that resource,
#	# then the server MUST NOT perform the requested method, unless
#	# required to do so because the resource's modification date fails
#	# to match that supplied in an If-Modified-Since header field in the
#	# request.
#
#	it "checks request's 'If-Modified-Since' header to see if it can return a 304 NOT MODIFIED response" do
#		params = {
#			'REQUEST_URI'            => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'         => 'GET',
#			'HTTP_IF_MODIFIED_SINCE' => 2.days.ago.httpdate,
#		  }
#
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#		mockheaders = mock( "response headers", :null_object => true )
#		etag = %q{"%s"} % [TEST_CHECKSUM]
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		
#		@metastore.should_receive( :[] ).with( TEST_UUID_OBJ ).
#			at_least( 1 ).
#			and_return( mockmetadata )
#		mockmetadata.should_receive( :modified ).
#			at_least( 1 ).
#			and_return( 8.days.ago )
#		mockmetadata.should_receive( :checksum ).
#			at_least( 1 ).
#			and_return( TEST_CHECKSUM )
#		
#		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
#		@response.should_receive( :header ).at_least(1).and_return( mockheaders )
#		mockheaders.should_receive( :[]= ).with( 'ETag', etag )
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#	
#
#	it "checks request's single cache token to see if it can return a 304 NOT MODIFIED response" do
#		etag = %q{"%s"} % 'd6af7eeb992c81ba7b3b0fac3693d7fd'
#		params = {
#			'REQUEST_URI'        => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'     => 'GET',
#			'HTTP_IF_NONE_MATCH' => etag,
#		  }
#
#		mockmetadata = mock( "meta proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@metastore.should_receive( :[] ).at_least(1).
#			with( TEST_UUID_OBJ ).and_return( mockmetadata )
#		mockmetadata.should_receive( :checksum ).
#			at_least(:twice).and_return( etag )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
#		@response.should_receive( :header ).at_least(1).and_return({})
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#	
#
#	it "checks all of request's cache tokens to see if it can return a 304 NOT MODIFIED response" do
#		etag = 'd6af7eeb992c81ba7b3b0fac3693d7fd'
#		params = {
#			'REQUEST_URI'        => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'     => 'GET',
#			'HTTP_IF_NONE_MATCH' => "W/\"v1.2\", \"#{etag}\"",
#		  }
#
#		mockmetadata = mock( "meta proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@metastore.should_receive( :[] ).at_least(1).
#			with( TEST_UUID_OBJ ).and_return( mockmetadata )
#		mockmetadata.should_receive( :checksum ).
#			at_least(:twice).and_return( etag )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
#		@response.should_receive( :header ).at_least(1).and_return({})
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#	
#
#	it "ignores weak cache tokens" do
#		etag = 'W/"v1.2"'
#		params = {
#			'REQUEST_URI'        => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'     => 'GET',
#			'HTTP_IF_NONE_MATCH' => "#{etag}",
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :status= ).with( HTTP::OK )
#		@response.should_receive( :header ).at_least(1).and_return({})
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "returns a 304 NOT MODIFIED for a GET with a wildcard If-None-Match" do
#		params = {
#			'REQUEST_URI'        => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'     => 'GET',
#			'HTTP_IF_NONE_MATCH' => "*",
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
#		@response.should_receive( :header ).at_least(1).and_return({})
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "ignores a wildcard 'If-None-Match' if the 'If-Modified-Since' header is out of date" do
#		# ThingFish.logger.level = Logger::DEBUG
#		params = {
#			'REQUEST_URI'            => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD'         => 'GET',
#			'HTTP_IF_NONE_MATCH'     => "*",
#			'HTTP_IF_MODIFIED_SINCE' => 2.days.ago.httpdate,
#		  }
#
#		testdata = 'this is some data for testing'
#		testbuf = testdata.dup
#		io = mock( 'io' )
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(1).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@metastore.should_receive( :[] ).
#			at_least(1).with( TEST_UUID_OBJ ).and_return( mockmetadata )
#		mockmetadata.should_receive( :modified ).
#			at_least(1).and_return( Time.now )
#		
#		@response.should_receive( :status= ).with( HTTP::OK )
#		@response.should_receive( :header ).at_least(1).and_return({})
#
#		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_yield( io )
#
#		@filestore.should_receive( :size ).and_return( 1024 )
#		@response.should_receive( :send_status ).with( 1024 )
#		@response.should_receive( :send_header )
#
#		# Simulate reading testdata from a file
#		io.should_receive( :read ).twice.
#			with( an_instance_of(Fixnum), '' ).
#			and_return do |size,buf|
#				buf << testbuf.slice!( 0, testbuf.length )
#				buf.empty? ? nil : buf.length
#			end
#		@response.should_receive( :write ).with( testdata ).and_return( testdata.length )
#
#		@response.should_receive( :finished )
#
#		@handler.process( @request, @response )
#	end
#
#
#	### PUT /«uuid» tests
#
#	it "handles PUT to /<<uuid>> for existing resource" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'CONTENT_TYPE'   => TEST_CONTENT_TYPE,
#			'REQUEST_METHOD' => 'PUT'
#		  }
#		io = StringIO.new( TEST_CONTENT )
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :start ).once.with( HTTP::OK, true ).
#			and_yield( @headers, @out )
#
#		@request.should_receive( :body ).and_return( io )
#		@filestore.should_receive( :store_io ).with( TEST_UUID_OBJ, io ).and_return( TEST_CHECKSUM )
# 		@metastore.
#			should_receive( :extract_default_metadata ).
#			with( TEST_UUID_OBJ, @request )
#		@metastore.should_receive( :[] ).
#			at_least(:once).with( TEST_UUID_OBJ ).
#			and_return( mockmetadata )
#		mockmetadata.should_receive( :checksum= ).with( TEST_CHECKSUM )
#			
#		@handler.process( @request, @response )
#	end
#
#
#	it "handles PUT to /<<uuid>> for new resource" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'CONTENT_TYPE'   => TEST_CONTENT_TYPE,
#			'REQUEST_METHOD' => 'PUT'
#		  }
#		io = StringIO.new( TEST_CONTENT )
#		mockmetadata = mock( "metadata proxy", :null_object => true )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( false )
#		@response.should_receive( :start ).once.with( HTTP::CREATED, true ).
#			and_yield( @headers, @out )
#
#		@request.should_receive( :body ).and_return( io )
#		@filestore.should_receive( :store_io ).once.with( TEST_UUID_OBJ, io ).and_return( TEST_CHECKSUM )
#		@metastore.
#			should_receive( :extract_default_metadata ).
#			with( TEST_UUID_OBJ, @request )
#		@metastore.should_receive( :[] ).
#			at_least(:once).with( TEST_UUID_OBJ ).
#			and_return( mockmetadata )
#		mockmetadata.should_receive( :checksum= ).with( TEST_CHECKSUM )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "returns a 413 REQUEST ENTITY TOO LARGE for a PUT to /<<uuid>> that exceeds quota" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'PUT'
#		}
#		body = StringIO.new( "~~~" * 1024 )
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@request.should_receive( :body ).and_return( body )
#		@filestore.should_receive( :store_io ).once.with( TEST_UUID_OBJ, body ).
#			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }
#		@response.should_receive( :start ).once.
#			with( HTTP::REQUEST_ENTITY_TOO_LARGE, true ).and_yield( @headers, @out )
#		@out.should_receive( :write ).once.with( /too large, sucka!/ )
#
#		@handler.process( @request, @response )
#	end
#
#
#	### DELETE /«UUID» tests
#
#	it "handles DELETE of /<<uuid>>" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'DELETE'
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )
#		@response.should_receive( :start ).once.with( HTTP::OK, true ).
#			and_yield( @headers, @out )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "handles DELETE of nonexistent /<<uuid>>" do
#		params = {
#			'REQUEST_URI'    => "/#{TEST_UUID_OBJ}",
#			'REQUEST_METHOD' => 'DELETE'
#		  }
#
#		@request.should_receive( :params ).at_least(2).and_return( params )
#		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( false )
#		@response.should_receive( :start ).once.with( HTTP::NO_CONTENT, true ).
#			and_yield( @headers, @out )
#
#		@handler.process( @request, @response )
#	end
#
#
#	it "adds a link to the manual to the main index page if the manual is installed" do
#		@handler.stub!( :resource_exists? ).and_return( true )
#		@handler.stub!( :get_resource ).and_return( "some content" )
#		@handler.stub!( :get_erb_resource ).and_return( ERB.new("Some stuff") )
#		@handler.make_index_content( '/' ).should == "Some stuff"
#	end
#
#
#	it "doesn't add a link to the manual if the manual is not installed" do
#		@handler.stub!( :resource_exists? ).and_return( false )
#		@handler.make_index_content( '/' ).should be_nil
#	end
#	

end

