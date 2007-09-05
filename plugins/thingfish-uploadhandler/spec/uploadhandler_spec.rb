#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'pathname'
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/handler_behavior'

	require 'thingfish/constants'
	require 'thingfish/handler/upload'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::TestHelpers


class ThingFish::UploadHandler
	public :handle_get_request,
		:handle_post_request
		
end


#####################################################################
###	C O N T E X T S
#####################################################################

unless defined?( SPECDIR )
	SPECDIR = Pathname.new( __FILE__ ).dirname
	DATADIR = SPECDIR + 'data'
end


describe ThingFish::UploadHandler do

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'upload', 'resource_dir' => resdir )
	end
	
	
	# Shared behaviors
	it_should_behave_like "A Handler"


	# Examples
	
	it "builds content for the index handler" do
		erb_resource = stub( 'erb resource', :result => 'some index stuff' )
		@handler.should_receive( :get_erb_resource ).
			with( /\w+\.rhtml$/ ).
			and_return( erb_resource )
		
		@handler.make_index_content( "/" ).should == 'some index stuff'
	end
	
end


describe ThingFish::UploadHandler, " (GET request)" do
	include ThingFish::Constants::Patterns

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'upload', 'resource_dir' => resdir )
		@request = mock( "request object", :null_object => true )
		@response = mock( "response object", :null_object => true )
		@headers = mock( "response headers", :null_object => true )
		
		@response.stub!( :headers ).and_return( @headers )
	end


	it "returns an upload form" do
		template = stub( "ERB template", :result => :rendered_output )

		@request.should_receive( :path_info ).and_return( '' )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		@response.should_receive( :body= ).with( :rendered_output )
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		
		@handler.handle_get_request( @request, @response )
	end
	
end


describe ThingFish::UploadHandler, " (POST request)" do
	include ThingFish::Constants::Patterns

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'upload', 'resource_dir' => resdir )
		@parser = mock( "mpm parser", :null_object => true )
		
		@handler.parser = @parser
		@request = mock( "request object", :null_object => true )
		@response = mock( "response object", :null_object => true )

		@request_headers = mock( "request headers", :null_object => true )
		@request.stub!( :headers ).and_return( @request_headers )
		@response_headers = mock( "response headers", :null_object => true )
		@response.stub!( :headers ).and_return( @response_headers )
	end
	

	### Examples
	
	it "correctly inserts file content from request with one upload" do
		mockfilestore = mock( "filestore", :null_object => true )
		mockmetastore = mock( "metastore", :null_object => true )
		
		mockdaemon = mock( "daemon", :null_object => true )
		mockdaemon.should_receive( :filestore ).and_return( mockfilestore )
		mockdaemon.should_receive( :metastore ).and_return( mockmetastore )
		
		@handler.listener = mockdaemon
		
		upload1 = mock( "upload tempfile 1", :null_object => true )
		
		files = {
			upload1 => { :extent => 2048, :format => 'text/plain' },
		}
		metadata = { :global_key => :global_value }

		@request.should_receive( :path_info ).
			at_least(:once).
			and_return( '' )
		@request.should_receive( :parse_multipart_body ).
			and_return([ files, metadata ])

		mockfilestore.should_receive( :store_io ).
			with( an_instance_of(UUID), upload1 ).
			once

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( /Uploaded \d+ file/ )
	
		@handler.handle_post_request( @request, @response )
	end
	
	
	it "correctly inserts file content from request with two uploads" do
		mockfilestore = mock( "filestore", :null_object => true )
		mockmetastore = mock( "metastore", :null_object => true )
		
		mockdaemon = mock( "daemon", :null_object => true )
		mockdaemon.should_receive( :filestore ).and_return( mockfilestore )
		mockdaemon.should_receive( :metastore ).and_return( mockmetastore )
		
		@handler.listener = mockdaemon
		
		upload1 = mock( "upload tempfile 1", :null_object => true )
		upload2 = mock( "upload tempfile 2", :null_object => true )
		
		files = {
			upload1 => { :extent => 2048, :format => 'text/plain' },
			upload2 => { :extent => 23823486, :format => 'image/png' },
		}
		metadata = { :global_key => :global_value }

		@request.should_receive( :path_info ).
			at_least(:once).
			and_return( '' )
		@request.should_receive( :parse_multipart_body ).
			and_return([ files, metadata ])

		# Store both of the uploads
		mockfilestore.should_receive( :store_io ).
			with( an_instance_of(UUID), upload1 ).
			once
		mockfilestore.should_receive( :store_io ).
			with( an_instance_of(UUID), upload2 ).
			once
		upload1.should_receive( :unlink )
		upload2.should_receive( :unlink )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( /Uploaded \d+ file/ )
	
		@handler.handle_post_request( @request, @response )
	end
	
end

# vim: set nosta noet ts=4 sw=4:
