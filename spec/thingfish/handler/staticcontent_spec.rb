#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish/handler'
require 'thingfish/handler/staticcontent'
require 'thingfish/behavior/handler'
require 'thingfish/testconstants'



#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::StaticContentHandler do

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :handler ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + '/tmp'
		ThingFish::Handler.create( 'staticcontent', '/foom', resdir )
	end

	before( :each ) do
		@daemon = mock( "thingfish daemon" ).as_null_object
		self.handler.on_startup( @daemon )

		@request          = mock( "request" ).as_null_object
		@request_headers  = mock( "request headers" ).as_null_object
		@response         = mock( "response" ).as_null_object
		@response_headers = mock( "response headers" ).as_null_object

		@request.stub!( :headers ).and_return( @request_headers )
		@response.stub!( :headers ).and_return( @response_headers )

		@pathname = mock( "Pathname" ).as_null_object
	end

	after( :all ) do
		reset_logging()
	end


	### Shared behaviors
	it_should_behave_like "a handler"


	it "does nothing if the requested path doesn't exist" do
		self.handler.stub!( :get_safe_path ).with( '/blorg.txt' ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( false )

		@response.should_not_receive( :status= )
		self.handler.find_static_file( '/blorg.txt', @request, @response )
	end


	it "refuses to serve directories" do
		self.handler.stub!( :get_safe_path ).with( '/blorgdir' ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( true )
		@pathname.should_receive( :file? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )
		self.handler.find_static_file( '/blorgdir', @request, @response )
	end


	it "refuses to serve files outside of its resource directory" do
		@response.should_not_receive( :status= )
		self.handler.find_static_file( '/../../etc/shadow', @request, @response )
	end


	it "respects file access permissions" do
		self.handler.stub!( :get_safe_path ).with( '/blorg.txt' ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( true )
		@pathname.should_receive( :file? ).and_return( true )
		@pathname.should_receive( :readable? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )
		self.handler.find_static_file( '/blorg.txt', @request, @response )
	end


	it "sets the appropriate content type for the file" do
		self.handler.stub!( :get_safe_path ).with( '/blorg.html' ).and_return( @pathname )

		@pathname.should_receive( :extname ).and_return( '.html' )
		@response.should_receive( :content_type= ).with( MIMETYPE_MAP['.html'] )

		stat = stub( "file stat", :mtime => 6, :size => 10, :ino => 23452 )
		@pathname.should_receive( :stat ).at_least( :once ).and_return( stat )
		@request.should_receive( :is_cached_by_client? ).and_return( false )

		@response_headers.
			should_receive( :[]= ).
			with( :content_length, 10 )

		@response.should_receive( :status= ).with( HTTP::OK )

		@pathname.should_receive( :open ).with('r').and_return( :an_IO )
		@response.should_receive( :body= ).with( :an_IO )

		self.handler.find_static_file( '/blorg.html', @request, @response )
	end


	it "defaults to a generic content type as fallback" do
		self.handler.stub!( :get_safe_path ).with( '/blorg.floop' ).and_return( @pathname )

		@pathname.should_receive( :extname ).and_return( '.floop' )
		@response.should_receive( :content_type= ).
			with( ThingFish::StaticContentHandler::DEFAULT_CONTENT_TYPE )

		stat = stub( "file stat", :mtime => 6, :size => 10, :ino => 23452 )
		@pathname.should_receive( :stat ).at_least( :once ).and_return( stat )
		@request.should_receive( :is_cached_by_client? ).and_return( false )

		@response_headers.
			should_receive( :[]= ).
			with( :content_length, 10 )

		@response.should_receive( :status= ).with( HTTP::OK )

		@pathname.should_receive( :open ).with('r').and_return( :an_IO )
		@response.should_receive( :body= ).with( :an_IO )

		self.handler.find_static_file( '/blorg.floop', @request, @response )
	end


	INDEX_FILE = ThingFish::StaticContentHandler::DEFAULT_INDEX_FILE

	it "serves index files" do
		self.handler.stub!( :get_safe_path ).
			with( '/this_is_a_directory_with_an_index_file' ).
			and_return( @pathname )

		@pathname.should_receive( :directory? ).and_return( true )
		@indexpath = mock( "index file Pathname object" )
		@pathname.should_receive( :+ ).with( INDEX_FILE ).and_return( @indexpath )

		@indexpath.should_receive( :exist? ).and_return( true )
		@indexpath.should_receive( :file? ).and_return( true )
		@indexpath.should_receive( :readable? ).and_return( true )

		@indexpath.should_receive( :extname ).and_return( '.floop' )
		@response.should_receive( :content_type= ).
			with( ThingFish::StaticContentHandler::DEFAULT_CONTENT_TYPE )

		stat = stub( "file stat", :mtime => 6, :size => 10, :ino => 23452 )
		@indexpath.should_receive( :stat ).at_least( :once ).and_return( stat )
		@request.should_receive( :is_cached_by_client? ).and_return( false )

		@response_headers.
			should_receive( :[]= ).
			with( :content_length, 10 )

		@response.should_receive( :status= ).with( HTTP::OK )

		@indexpath.should_receive( :open ).with('r').and_return( :an_IO )
		@response.should_receive( :body= ).with( :an_IO )

		self.handler.find_static_file( '/this_is_a_directory_with_an_index_file', @request, @response )
	end


	it "sends a 304 NOT MODIFIED response if the request's etag header matches" do
		self.handler.stub!( :get_safe_path ).
			with( '/barrel/o/pork.html' ).
			and_return( @pathname )

		mtime = 3.days.ago

		@pathname.should_receive( :directory? ).and_return( false )
		@pathname.should_receive( :exist? ).and_return( true )
		@pathname.should_receive( :file? ).and_return( true )
		@pathname.should_receive( :readable? ).and_return( true )

		stat = stub( "file stat", :mtime => mtime, :size => 10, :ino => 23452 )
		@pathname.should_receive( :stat ).at_least( :once ).and_return( stat )

		@request.should_receive( :is_cached_by_client? ).
			with( "%d-%d-%d" % [ mtime.to_i, 10, 23452 ], mtime ).
			and_return( true )

		@response.should_receive( :status= ).with( HTTP::NOT_MODIFIED )

		@pathname.should_not_receive( :open ).with('r').and_return( :an_IO )
		@response.should_not_receive( :body= ).with( :an_IO )

		self.handler.find_static_file( '/barrel/o/pork.html', @request, @response )
	end


end


