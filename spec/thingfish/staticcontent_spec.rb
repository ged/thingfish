#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

begin
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/helpers'
	require 'spec/lib/constants'
	require 'spec/lib/handler_behavior'

	require "thingfish/handler"
	require "thingfish/handler/staticcontent"
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestHelpers


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::StaticContentHandler do
	include ThingFish::TestHelpers
	
	before( :all ) do
		setup_logging( :fatal )
	end
	


	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + '/tmp'
		@handler = ThingFish::Handler.create( 'staticcontent', resdir )

		@listener = mock( "thingfish daemon", :null_object => true )
		@handler.listener = @listener

		@request          = mock( "request", :null_object => true )
		@request_headers  = mock( "request headers", :null_object => true )
		@response         = mock( "response", :null_object => true )
		@response_headers = mock( "response headers", :null_object => true )

		@request.stub!( :headers ).and_return( @request_headers )
		@response.stub!( :headers ).and_return( @response_headers )

		@pathname = mock( "Pathname", :null_object => true )
	end	
	
	### Shared behaviors
	it_should_behave_like "A Handler"


	it "does nothing if the requested path doesn't exist" do
		@handler.stub!( :get_safe_path ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( false )

		@response.should_not_receive( :status= )
		@handler.handle_get_request( @request, @response )
	end


	it "refuses to serve directories" do
		@handler.stub!( :get_safe_path ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( true )
		@pathname.should_receive( :file? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )
		@handler.handle_get_request( @request, @response )
	end


	it "refuses to serve files outside of its resource directory" do
		@request.should_receive( :path_info ).
			and_return( '../../etc/shadow' )

		@response.should_not_receive( :status= )
		@handler.handle_get_request( @request, @response )
	end


	it "respects file access permissions" do
		@handler.stub!( :get_safe_path ).and_return( @pathname )
		@pathname.should_receive( :exist? ).and_return( true )
		@pathname.should_receive( :file? ).and_return( true )
		@pathname.should_receive( :readable? ).and_return( false )

		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )
		@handler.handle_get_request( @request, @response )
	end


	it "sets the appropriate content type for the file" do
		@handler.stub!( :get_safe_path ).and_return( @pathname )

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

		@handler.handle_get_request( @request, @response )
	end


	it "defaults to a generic content type as fallback" do
		@handler.stub!( :get_safe_path ).and_return( @pathname )

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

		@handler.handle_get_request( @request, @response )
	end


	INDEX_FILE = ThingFish::StaticContentHandler::DEFAULT_INDEX_FILE

	it "serves index files" do
		@request.should_receive( :path_info ).
			and_return( 'this_is_a_directory_with_an_index_file' )
		@handler.stub!( :get_safe_path ).and_return( @pathname )
		
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

		@handler.handle_get_request( @request, @response )
	end
	
	
	it "sends a 304 NOT MODIFIED response if the request's etag header matches" do
		@request.should_receive( :path_info ).
			and_return( 'barrel/o/pork.html' )
		@handler.stub!( :get_safe_path ).and_return( @pathname )
		
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

		@handler.handle_get_request( @request, @response )
	end
	
	
end

