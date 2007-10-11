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
	require 'thingfish/handler/formupload'
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


class ThingFish::FormUploadHandler
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


describe ThingFish::FormUploadHandler do

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'formupload', 'resource_dir' => resdir )
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


describe ThingFish::FormUploadHandler, " (GET request)" do
	include ThingFish::Constants::Patterns

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'formupload', 'resource_dir' => resdir )
		@request = mock( "request object", :null_object => true )
		@response = mock( "response object", :null_object => true )
		@headers = mock( "response headers", :null_object => true )
		
		@response.stub!( :headers ).and_return( @headers )
	end


	it "returns an upload form" do
		template = stub( "ERB template", :result => :rendered_output )
		formtemplate = stub( "ERB form template", :result => :rendered_form_output )

		@request.should_receive( :path_info ).and_return( '' )

		@handler.should_receive( :get_erb_resource ).
			with( 'upload.rhtml' ).
			and_return( template )
		@handler.should_receive( :get_erb_resource ).
			with( 'uploadform.rhtml' ).
			and_return( formtemplate )
		@response.should_not_receive( :body= ).with( :rendered_form_output )
		@response.should_receive( :body= ).with( :rendered_output )
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		
		@handler.handle_get_request( @request, @response )
	end
	
end


describe ThingFish::FormUploadHandler, " (POST request)" do
	include ThingFish::Constants::Patterns

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'formupload', 'resource_dir' => resdir )
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
	
	it "inserts upload file content from request" do
		mockfilestore = mock( "filestore", :null_object => true )
		mockmetastore = mock( "metastore", :null_object => true )
		
		mockdaemon = mock( "daemon", :null_object => true )
		mockdaemon.should_receive( :filestore ).and_return( mockfilestore )
		mockdaemon.should_receive( :metastore ).and_return( mockmetastore )
		
		@handler.listener = mockdaemon
		
		upload1 = mock( "upload tempfile 1", :null_object => true )
		metadata = mock( "merged metadata hash", :null_object => true )
		metadata.should_receive( :[] ).
			with( :uuid ).
			at_least( :once ).
			and_return( TEST_UUID )

		@request.should_receive( :path_info ).
			at_least(:once).
			and_return( '' )
		@request.should_receive( :each_body ).
			and_yield( upload1, metadata )

		mockdaemon.should_receive( :store_resource ).
			with( upload1, metadata ).
			once

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( /Uploaded \d+ file/ )
	
		@handler.handle_post_request( @request, @response )
	end
end

# vim: set nosta noet ts=4 sw=4:
