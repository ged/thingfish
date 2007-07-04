#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'pathname'
require 'logger'
require 'spec/runner'
require 'stringio'
require 'thingfish/constants'

require 'thingfish/handler/upload'


#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

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
	'CONTENT_LENGTH'       => '123456789'
}

unless defined?( SPECDIR )
	SPECDIR = Pathname.new( __FILE__ ).dirname
	DATADIR = SPECDIR + 'data'
end


### Create a stub request prepopulated with HTTP headers and form data
def load_fixtured_request( filename )
	datafile = DATADIR + filename
	data = StringIO.new( datafile.read )
	
	request = stub( "request object",
		:params => UPLOAD_HEADERS,
		:body => data
	  )

	return request
end


describe ThingFish::UploadHandler do
	include ThingFish::Constants::Patterns

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	

	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'upload', 'resource_dir' => resdir )
		@params = {
			'REQUEST_METHOD' => 'POST',
			'REQUEST_URI' => '/upload',
		}
	end
	
	it "returns an error response for a non-multipart form post" do
		@params['HTTP_CONTENT_TYPE'] = 'application/x-www-form-urlencoded'

		request = stub( "request object", :params => @params )
		response = mock( "response object", :null_object => true )
		outhandle = mock( "output filehandle" )
		
		response.should_receive( :start ).
			with( HTTP::BAD_REQUEST, true ).
			and_yield( nil, outhandle )
		outhandle.should_receive( :write ).with( /unable to parse/i )
			
		@handler.process( request, response )
	end
	
	
	it "returns an error response when its parser throws an error" do
		@params['HTTP_CONTENT_TYPE'] = 'multipart/form-data; boundary=-----testboundary'
		
		body = StringIO.new( "---totally_the_wrong_boundary\r\nand some other stuff" )
		request = stub( "request object", :params => @params, :body => body )
		response = mock( "response object", :null_object => true )
		outhandle = mock( "output filehandle" )

		response.should_receive( :start ).
			with( HTTP::BAD_REQUEST, true ).
			and_yield( nil, outhandle )
		outhandle.should_receive( :write ).with( /no initial boundary/i )
		
		@handler.process( request, response )
	end

	it "correctly inserts file content from request with one upload" do
		request = load_fixtured_request( 'singleupload.form' )
		response = mock( "response object", :null_object => true )
		outheaders = mock( "response headers", :null_object => true )
		outhandle = mock( "response filehandle", :null_object => true )
		mockfilestore = mock( "filestore", :null_object => true )
		mockmetastore = mock( "metastore", :null_object => true )
		
		mockhandler = mock( "daemon", :null_object => true )
		mockhandler.should_receive( :filestore ).and_return( mockfilestore )
		mockhandler.should_receive( :metastore ).and_return( mockmetastore )
		
		@handler.listener = mockhandler
		
		mockfilestore.should_receive( :store_io ).
			with( an_instance_of(UUID), an_instance_of(Tempfile) ).
			once
		response.should_receive( :start ).
			with( HTTP::CREATED, true ).
			and_yield( outheaders, outhandle )

		@handler.process( request, response )
	end
	
	
	it "correctly inserts file content from request with two uploads" do
		request = load_fixtured_request( '2_images.form' )
		response = mock( "response object", :null_object => true )
		outheaders = mock( "response headers", :null_object => true )
		outhandle = mock( "response filehandle", :null_object => true )
		mockfilestore = mock( "filestore", :null_object => true )
		mockmetastore = mock( "metastore", :null_object => true )
		
		mockhandler = mock( "daemon", :null_object => true )
		mockhandler.should_receive( :filestore ).and_return( mockfilestore )
		mockhandler.should_receive( :metastore ).and_return( mockmetastore )
		
		@handler.listener = mockhandler
		
		mockfilestore.should_receive( :store_io ).
			with( an_instance_of(UUID), an_instance_of(Tempfile) ).
			twice
		response.should_receive( :start ).
			with( HTTP::CREATED, true ).
			and_yield( outheaders, outhandle )

		@handler.process( request, response )
	end
	
	# file chunker detection
	# 	parsing of filename
	# 	parsing of content-type

end

# vim: set nosta noet ts=4 sw=4:
