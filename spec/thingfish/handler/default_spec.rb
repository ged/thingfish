#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'
require 'time'
require 'stringio'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/handler/default'
require 'thingfish/behavior/handler'


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::DefaultHandler do

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :handler ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent.parent + 'var/www'
		ThingFish::DefaultHandler.new( '/', :resource_dir => resdir )
	end

	before(:each) do
		@daemon           = mock( "thingfish daemon" )
		@filestore        = mock( "thingfish filestore" )
		@metastore        = mock( "thingfish metastore" )

		@config = ThingFish::Config.new

		@mockmetadata 	  = mock( "metadata proxy" )
		@metastore.stub!( :[] ).and_return( @mockmetadata )
		@mockmetadata.stub!( :modified ).and_return('Wed Aug 29 21:24:09 -0700 2007')

		@daemon.stub!( :filestore ).and_return( @filestore )
		@daemon.stub!( :metastore ).and_return( @metastore )
		@daemon.stub!( :config ).and_return( @config )

		urimap = stub( "urimap", :register_first => nil )
		@daemon.stub!( :urimap ).and_return( urimap )

		self.handler.on_startup( @daemon )

		@request          = mock( "request" )
		@request_headers  = mock( "request headers" )
		@response         = mock( "response" )
		@response_headers = mock( "response headers" )

		@request.stub!( :headers ).and_return( @request_headers )
		@response.stub!( :headers ).and_return( @response_headers )
		@request.stub!( :has_multipart_body? ).and_return( false )
	end

	after( :all ) do
		reset_logging()
	end


	### Shared behaviors
	it_should_behave_like "a handler"


	### Index requests

	it "handles GET / with a hash of server metadata" do
		@daemon.should_receive( :handler_info ).and_return( :a_hash_of_handler_info )
		@daemon.should_receive( :filter_info ).and_return( :a_hash_of_filter_info )

		@response.should_receive( :body= ).with( an_instance_of(Hash) )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :data ).at_least( :once ).and_return( {} )
		@response.should_receive( :status= ).with( HTTP::OK )

		self.handler.handle_get_request( '', @request, @response )
	end


	it "does not modify the response on unknown URIs" do
		@response.should_not_receive( :body= )
		@response.should_not_receive( :content_type= )

		self.handler.handle_get_request( '/poke', @request, @response )
	end


	it "handles POST /" do
		body = StringIO.new( TEST_CONTENT )
		metadata = {}

		full_metadata = mock( "metadata fetched from the store" )
		@metastore.should_receive( :get_properties ).and_return( full_metadata )

		@request.should_receive( :bodies ).twice.and_return({ body => metadata })

		@response_headers.should_receive( :[]= ).
			with( :location, %r{/#{TEST_UUID}} )
		@response.should_receive( :body= ).with( full_metadata )
		@response.should_receive( :status= ).once.with( HTTP::CREATED )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		@daemon.should_receive( :store_resource ).
			with( body, metadata ).
			and_return( TEST_UUID )
		@daemon.should_receive( :store_related_resources ).
			with( body, TEST_UUID, @request )

		self.handler.handle_post_request( '', @request, @response )
	end


	it "raises a ThingFish::RequestEntityTooLargeError for an upload to / that exceeds quota" do
		body = StringIO.new( TEST_CONTENT )
		md = {}

		@request.should_receive( :bodies ).twice.and_return({ body => md })
		@daemon.should_receive( :store_resource ).
			with( body, md ).
			and_return { raise ThingFish::FileStoreQuotaError, "too NARROW, sucka!" }

		expect {
			self.handler.handle_post_request( '', @request, @response )
		}.to raise_error( ThingFish::RequestEntityTooLargeError, /too NARROW/ )
	end


	it "sends a METHOD_NOT_ALLOWED response for PUT to /" do
		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'GET, HEAD, POST' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		self.handler.handle_put_request( '', @request, @response )
	end


	it "sends a METHOD_NOT_ALLOWED response for DELETE to /" do
		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'GET, HEAD, POST' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		self.handler.handle_delete_request( '', @request, @response )
	end


	it "raises a NOT_IMPLEMENTED exception for multipart POST to /" do
		@request.should_receive( :bodies ).twice.and_return({ :body1 => :md1, :body2 => :md2 })

		lambda {
			self.handler.handle_post_request( '', @request, @response )
		}.should raise_error( ThingFish::NotImplementedError, /not implemented/ )
	end



	### GET /«UUID» request tests

	it "normalizes the case of UUIDs" do
		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@mockmetadata.should_receive( :checksum ).at_least( :once ).and_return( :a_checksum )
		@mockmetadata.should_receive( :format ).and_return( :a_mimetype )

		@filestore.should_receive( :size ).with( TEST_UUID_OBJ ).and_return( 888888 )
		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_return( :an_io )

		@request_headers.stub!( :[] ).and_return( nil )
		@request.stub!( :http_method ).and_return( :GET )
		@request.stub!( :is_cached_by_client? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( :a_mimetype )
		@response.should_receive( :body= ).with( :an_io )

		@response_headers.should_receive( :[]= ).with( :etag, /a_checksum/ )
		@response_headers.should_receive( :[]= ).with( :expires, VALID_HTTPDATE )
		@response_headers.should_receive( :[]= ).with( :content_length, 888888 )

		@request.stub!( :query_args ).and_return( {} )

		self.handler.handle_get_request( TEST_UUID.upcase, @request, @response )
	end


	it "handles GET /{uuid}" do
		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@mockmetadata.should_receive( :checksum ).at_least( :once ).and_return( :a_checksum )
		@mockmetadata.should_receive( :format ).and_return( :a_mimetype )

		@filestore.should_receive( :size ).with( TEST_UUID_OBJ ).and_return( 888888 )
		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_return( :an_io )

		@request_headers.stub!( :[] ).and_return( nil )
		@request.stub!( :http_method ).and_return( :GET )
		@request.stub!( :is_cached_by_client? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( :a_mimetype )
		@response.should_receive( :body= ).with( :an_io )

		@response_headers.should_receive( :[]= ).with( :etag, /a_checksum/ )
		@response_headers.should_receive( :[]= ).with( :expires, VALID_HTTPDATE )
		@response_headers.should_receive( :[]= ).with( :content_length, 888888 )

		# No 'attach' query arg means no content-disposition set
		@request.stub!( :query_args ).and_return( {} )

		self.handler.handle_get_request( TEST_UUID, @request, @response )
	end


	it "sets the content disposition of the requested resource if asked to do so" do
		time = stub( "Fake time object", :rfc822 => "Wed, 29 Aug 2007 21:24:09 -0700" )
		Time.stub!( :parse ).and_return( time )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@mockmetadata.should_receive( :checksum ).at_least( :once ).and_return( :a_checksum )
		@mockmetadata.should_receive( :format ).and_return( :a_mimetype )

		@filestore.should_receive( :size ).with( TEST_UUID_OBJ ).and_return( 888888 )
		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_return( :an_io )

		@request_headers.stub!( :[] ).and_return( nil )
		@request.stub!( :http_method ).and_return( :GET )
		@request.stub!( :is_cached_by_client? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( :a_mimetype )
		@response.should_receive( :body= ).with( :an_io )

		query_args = mock( "uri query arguments" )
		@request.stub!( :query_args ).and_return( query_args )
		query_args.should_receive( :has_key? ).with( 'attach' ).and_return( true )
		query_args.should_receive( :[] ).with( 'attach' ).and_return( nil )

		@response_headers.should_receive( :[]= ).with( :etag, /a_checksum/ )
		@response_headers.should_receive( :[]= ).with( :expires, VALID_HTTPDATE )
		@response_headers.should_receive( :[]= ).with( :content_length, 888888 )
		@response_headers.
			should_receive( :[]= ).
			with( :content_disposition,
				'attachment; ' +
				'filename="potap.mp3"; ' +
				'modification-date="Wed, 29 Aug 2007 21:24:09 -0700"' )

		@mockmetadata.should_receive( :title ).and_return( 'potap.mp3' )

		self.handler.handle_get_request( TEST_UUID, @request, @response )
	end


	it "sets the content disposition filename of the requested resource" do
		time = stub( "Fake time object", :rfc822 => "Wed, 29 Aug 2007 21:24:09 -0700" )
		Time.stub!( :parse ).and_return( time )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@mockmetadata.should_receive( :checksum ).at_least( :once ).and_return( :a_checksum )
		@mockmetadata.should_receive( :format ).and_return( :a_mimetype )

		@filestore.should_receive( :size ).with( TEST_UUID_OBJ ).and_return( 888888 )
		@filestore.should_receive( :fetch_io ).with( TEST_UUID_OBJ ).and_return( :an_io )

		@request_headers.stub!( :[] ).and_return( nil )
		@request.stub!( :http_method ).and_return( :GET )
		@request.stub!( :is_cached_by_client? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( :a_mimetype )
		@response.should_receive( :body= ).with( :an_io )

		query_args = mock( "uri query arguments" )
		@request.stub!( :query_args ).and_return( query_args )
		query_args.should_receive( :has_key? ).with( 'attach' ).and_return( true )
		query_args.should_receive( :[] ).with( 'attach' ).and_return( 'ukraine_rapper.mp3' )

		@response_headers.should_receive( :[]= ).with( :etag, /a_checksum/ )
		@response_headers.should_receive( :[]= ).with( :expires, VALID_HTTPDATE )
		@response_headers.should_receive( :[]= ).with( :content_length, 888888 )
		@response_headers.
			should_receive( :[]= ).
			with( :content_disposition,
				'attachment; ' +
				'filename="ukraine_rapper.mp3"; ' +
				'modification-date="Wed, 29 Aug 2007 21:24:09 -0700"' )

		@mockmetadata.should_not_receive( :title )

		self.handler.handle_get_request( TEST_UUID, @request, @response )
	end


	it "responds with a 404 NOT FOUND for a GET to a nonexistent /{uuid}" do
		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :body= ).with( /not found/i )
		@response.should_receive( :content_type= ).with( 'text/plain' )

		self.handler.handle_get_request( TEST_UUID, @request, @response )
	end


	it "sends a METHOD_NOT_ALLOWED response for POST to /{uuid}" do
		@response_headers.
			should_receive( :[]= ).
			with( :allow, 'DELETE, GET, HEAD, PUT' )
		@response.should_receive( :status= ).with( HTTP::METHOD_NOT_ALLOWED )
		@response.should_receive( :body= ).with( /not allowed/i )

		@request.stub!( :http_method ).and_return( :POST )
		self.handler.handle_post_request( TEST_UUID, @request, @response )
	end


	### Caching tests

	it "checks the request to see if it can return a 304 NOT MODIFIED response" do
		modtime = 8.days.ago

		etag = %q{"%s"} % [TEST_CHECKSUM]

		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )

		@mockmetadata.should_receive( :modified ).at_least( 1 ).and_return( modtime )
		@mockmetadata.should_receive( :checksum ).at_least( 1 ).and_return( TEST_CHECKSUM )

		@request.should_receive( :is_cached_by_client? ).with( TEST_CHECKSUM, modtime ).
			and_return( true )

		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )
		@response_headers.should_receive( :[]= ).with( :etag, etag )
		@response_headers.should_receive( :[]= ).with( :expires, VALID_HTTPDATE )

		self.handler.handle_get_request( TEST_UUID, @request, @response )
	end


	### PUT /«uuid» tests

	it "handles PUT to /{uuid} for existing resource" do
		io = StringIO.new( TEST_CONTENT )
		metadata = stub( "metadata hash" )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( true )

		@request.should_receive( :bodies ).with().twice.and_return({ io => {} })
		@daemon.should_receive( :store_resource ).
			with( io, an_instance_of(Hash), TEST_UUID_OBJ ).
			and_return( TEST_CHECKSUM )
		@daemon.should_receive( :store_related_resources ).
			with( io, TEST_UUID_OBJ, @request )
		@daemon.should_receive( :purge_related_resources ).with( TEST_UUID_OBJ )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@metastore.should_receive( :get_properties ).
			with( TEST_UUID_OBJ ).
			and_return( :the_body )

		@response.should_receive( :body= ).with( :the_body )

		self.handler.handle_put_request( TEST_UUID, @request, @response )
	end


	it "raises a NOT_IMPLEMENTED exception for multipart PUT to /<uuid>" do
		@request.should_receive( :bodies ).twice.and_return({ :body1 => :md1, :body2 => :md2 })

		lambda {
			self.handler.handle_put_request( TEST_UUID, @request, @response )
		}.should raise_error( ThingFish::NotImplementedError, /not implemented/ )
	end


	it "handles PUT to /{uuid} for new resource" do
		io = StringIO.new( TEST_CONTENT )

		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )

		@request.should_receive( :bodies ).twice().and_return({ io => {} })
		@daemon.should_receive( :store_resource ).
			with( io, an_instance_of(Hash), TEST_UUID_OBJ ).
			and_return( TEST_CHECKSUM )
		@daemon.should_receive( :store_related_resources ).
			with( io, TEST_UUID_OBJ, @request )

		@daemon.should_receive( :purge_related_resources ).with( TEST_UUID_OBJ )

		@response.should_receive( :status= ).with( HTTP::CREATED )
		@response_headers.should_receive( :[]= ).
			with( :location, /#{TEST_UUID}/i )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		@metastore.should_receive( :get_properties ).
			with( TEST_UUID_OBJ ).
			and_return( :the_body )

		@response.should_receive( :body= ).with( :the_body )

		self.handler.handle_put_request( TEST_UUID, @request, @response )
	end

	it "raises a ThingFish::RequestEntityTooLargeError for a PUT to /{uuid} that exceeds quota" do
		body = StringIO.new( "~~~" * 1024 )
		md = {}

		@request.should_receive( :bodies ).twice().and_return({ body => md })
		@daemon.should_receive( :store_resource ).
			with( body, md, TEST_UUID_OBJ ).
			and_return { raise ThingFish::FileStoreQuotaError, "too large, sucka!" }
		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).and_return( true )

		expect {
			self.handler.handle_put_request( TEST_UUID, @request, @response )
		}.to raise_error( ThingFish::RequestEntityTooLargeError, /too large/ )
	end



	### DELETE /«UUID» tests

	it "handles DELETE of /{uuid}" do
		@filestore.should_receive( :has_file? ).with( TEST_UUID_OBJ ).
			and_return( true )
		@filestore.should_receive( :delete ).with( TEST_UUID_OBJ )
		@metastore.should_receive( :delete_resource ).with( TEST_UUID_OBJ ).
			and_return( true )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /resource '#{TEST_UUID}' deleted/i )

		self.handler.handle_delete_request( TEST_UUID, @request, @response )
	end


	it "returns a NOT_FOUND for a DELETE of nonexistent /{uuid}" do
		@filestore.should_receive( :has_file? ).
			with( TEST_UUID_OBJ ).
			and_return( false )
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /not found/i )

		self.handler.handle_delete_request( TEST_UUID, @request, @response )
	end


	### HTML filter interface

	it "builds an index of all the handlers when asked for HTML for /" do
		template = mock( "template" )
		body = stub( "body data-structure" )

		handler1 = mock( 'A handler' )
		handler2 = mock( 'Another handler' )

		urimap = ThingFish::UriMap.new
		urimap.register( '/', handler1 )
		urimap.register( '/runkagunk', handler2 )
		@daemon.stub!( :urimap ).and_return( urimap )

		self.handler.stub!( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).
			with( an_instance_of(Binding) ).
			and_return( :rendered_output )

		handler1.should_receive( :is_a? ).with( ThingFish::Handler ).and_return( true )
		handler1.should_receive( :make_index_content ).with( '' ).
			and_return( "handler1 stuff" )
		handler2.should_receive( :is_a? ).with( ThingFish::Handler ).and_return( true )
		handler2.should_receive( :make_index_content ).with( '/runkagunk' ).
			and_return( "handler2 stuff" )

		self.handler.make_html_content( body, @request, @response ).
			should == :rendered_output
	end

end

