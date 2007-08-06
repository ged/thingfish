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


#####################################################################
###	C O N T E X T S
#####################################################################

UPLOAD_HEADERS = {
	'REQUEST_METHOD'       => 'POST',
	'HTTP_HOST'            => 'localhost:3474',
	'HTTP_USER_AGENT'      => 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.4) Gecko/20070515 Firefox/2.0.0.4',
	'HTTP_ACCEPT'          => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
	'HTTP_ACCEPT_LANGUAGE' => 'en-us,en;q=0.5',
	'HTTP_ACCEPT_ENCODING' => 'gzip,deflate',
	'HTTP_ACCEPT_CHARSET'  => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
	'HTTP_KEEP_ALIVE'      => '300',
	'HTTP_CONNECTION'      => 'keep-alive',
	'HTTP_REFERER'         => 'http://localhost:3474/upload',
	'HTTP_CONTENT_TYPE'    => 'multipart/form-data; boundary=sillyBoundary',
	'CONTENT_LENGTH'       => '123456789',
	'PATH_INFO'            => '',
}

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
	
	it "returns a METHOD_NOT_ALLOWED response for requests other than GET or POST" do
		params = {
			'REQUEST_METHOD' => 'TRACE',
			'REQUEST_URI'    => '/upload',
			'PATH_INFO'      => '',
		}
		
		request = stub( "request object", :params => params )
		response = mock( "response object", :null_object => true )
		outhandle = mock( "output filehandle" )
		headers = mock( "response headers", :null_object => true )

		response.should_receive( :start ).
			with( HTTP::METHOD_NOT_ALLOWED, true ).
			and_yield( headers, outhandle )
		headers.should_receive( :[]= ).
			with( 'Allow', 'GET, POST' )
		outhandle.should_receive( :write ).
			with( /not allowed/i )
		
		@handler.process( request, response )
	end


	it "builds content for the index handler" do
		erb_resource = stub( 'erb resource', :result => 'some index stuff' )
		@handler.should_receive( :get_erb_resource ).
			with( /\w+\.html$/ ).
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
		@params = {
			'REQUEST_METHOD' => 'GET',
			'REQUEST_URI'    => '/upload',
			'PATH_INFO'      => '',
		}
	end


	it "returns an upload form" do
		request = stub( "request object", :params => @params )
		response = mock( "response object", :null_object => true )
		outhandle = mock( "output filehandle" )
		template = stub( "ERB template", :result => :rendered_output )
		headers = mock( "response headers", :null_object => true )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		response.should_receive( :start ).
			with( HTTP::OK, true ).
			and_yield( headers, outhandle )
		headers.should_receive( :[]= ).with( /content-type/i, 'text/html' )
		outhandle.should_receive( :write ).with( :rendered_output )
		
		@handler.process( request, response )
	end
	
end

describe ThingFish::UploadHandler, " (POST request)" do
	include ThingFish::Constants::Patterns

	### This all needs to be reworked once the request/response model is done
	
	# before( :all ) do
	# 	ThingFish.logger.level = Logger::FATAL
	# end
	# 
	# before( :each ) do
	# 	resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	#     @handler  = ThingFish::Handler.create( 'upload', 'resource_dir' => resdir )
	# 	@parser = mock( "mpm parser", :null_object => true )
	# 	
	# 	@handler.parser = @parser
	# 	
	# 	@params = {
	# 		'REQUEST_METHOD' => 'POST',
	# 		'REQUEST_URI'    => '/upload',
	# 		'PATH_INFO'      => '',
	# 	}
	# end
	# 
	# 
	# it "returns an error response for a non-multipart form post" do
	# 	@params['HTTP_CONTENT_TYPE'] = 'application/x-www-form-urlencoded'
	# 
	# 	request = stub( "request object", :params => @params )
	# 	response = mock( "response object", :null_object => true )
	# 	outhandle = mock( "output filehandle" )
	# 	
	# 	response.should_receive( :start ).
	# 		with( HTTP::BAD_REQUEST, true ).
	# 		and_yield( nil, outhandle )
	# 	outhandle.should_receive( :write ).with( /unable to parse/i )
	# 		
	# 	@handler.process( request, response )
	# end
	# 
	# 
	# it "returns an error response when its parser throws an error" do
	# 	request = stub( "request object", :params => @params, :body => body )
	# 	response = mock( "response object", :null_object => true )
	# 	outhandle = mock( "output filehandle" )
	# 
	# 	@parser.should_receive( :parse ).and_raise( ThingFish::RequestError )
	# 	response.should_receive( :start ).
	# 		with( HTTP::BAD_REQUEST, true ).
	# 		and_yield( nil, outhandle )
	# 	outhandle.should_receive( :write ).with( /no initial boundary/i )
	# 	
	# 	@handler.process( request, response )
	# end
	# 
	# it "correctly inserts file content from request with one upload" do
	# 	request = mock( "request object", :null_object => true )
	# 	response = mock( "response object", :null_object => true )
	# 	outheaders = mock( "response headers", :null_object => true )
	# 	outhandle = mock( "response filehandle", :null_object => true )
	# 	mockfilestore = mock( "filestore", :null_object => true )
	# 	mockmetastore = mock( "metastore", :null_object => true )
	# 	
	# 	mockhandler = mock( "daemon", :null_object => true )
	# 	mockhandler.should_receive( :filestore ).and_return( mockfilestore )
	# 	mockhandler.should_receive( :metastore ).and_return( mockmetastore )
	# 	
	# 	@handler.listener = mockhandler
	# 	
	# 	mockfilestore.should_receive( :store_io ).
	# 		with( an_instance_of(UUID), an_instance_of(Tempfile) ).
	# 		once
	# 	response.should_receive( :start ).
	# 		with( HTTP::CREATED, true ).
	# 		and_yield( outheaders, outhandle )
	# 
	# 	@handler.process( request, response )
	# end
	# 
	# 
	# it "correctly inserts file content from request with two uploads" do
	# 	request = mock( "request object", :null_object => true )
	# 	response = mock( "response object", :null_object => true )
	# 	outheaders = mock( "response headers", :null_object => true )
	# 	outhandle = mock( "response filehandle", :null_object => true )
	# 	mockfilestore = mock( "filestore", :null_object => true )
	# 	mockmetastore = mock( "metastore", :null_object => true )
	# 	
	# 	mockhandler = mock( "daemon", :null_object => true )
	# 	mockhandler.should_receive( :filestore ).and_return( mockfilestore )
	# 	mockhandler.should_receive( :metastore ).and_return( mockmetastore )
	# 	
	# 	@handler.listener = mockhandler
	# 	
	# 	mockfilestore.should_receive( :store_io ).
	# 		with( an_instance_of(UUID), an_instance_of(Tempfile) ).
	# 		twice
	# 	response.should_receive( :start ).
	# 		with( HTTP::CREATED, true ).
	# 		and_yield( outheaders, outhandle )
	# 
	# 	@handler.process( request, response )
	# end
	
end

# vim: set nosta noet ts=4 sw=4:
