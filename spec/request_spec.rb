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
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/request'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestConstants
include ThingFish::Constants

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Request do
	
	before( :each ) do
		@mongrel_request = mock( "mongrel request", :null_object => true )
		config = stub( "Config object", :spooldir => 'sdfgsd', :bufsize => 3 )
		@request = ThingFish::Request.new( @mongrel_request, config )
	end

	
	it "wraps and delegates to a mongrel request object" do
		@mongrel_request.should_receive( :body ).and_return( :the_body )
		@request.body.should == :the_body
	end
	
	
	it "extracts HTTP headers as simple headers from its mongrel request" do
		params = {
			'HTTP_ACCEPT' => 'Accept',
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.headers['accept'].should == 'Accept'
		@request.headers['Accept'].should == 'Accept'
		@request.headers['ACCEPT'].should == 'Accept'
	end
	
	
	it "parses the 'Accept' header into one or more AcceptParam structs" do
		params = {
			# 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'
			'HTTP_ACCEPT' => TEST_ACCEPT_HEADER,
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.accepted_types.should have(3).members
		@request.accepted_types[0].mediatype.should == 'application/x-yaml'
		@request.accepted_types[1].mediatype.should == 'application/json'
		@request.accepted_types[2].mediatype.should == 'text/xml'
	end
	
	it "knows when it does not have a multipart/form-data body" do
		params = {
			'Content-type' => 'application/x-bungtruck'
		}

		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		@request.should_not have_multipart_body()
	end
	
	it "knows when it has a multipart/form-data body" do
		params = {
			'HTTP_CONTENT_TYPE' => 'multipart/form-data; boundary="greatgoatsofgerta"'
		}

		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		@request.should have_multipart_body()
	end
	
	
	it "provides an interface to parse a multipart/form-data body" do
		params = {
			'HTTP_CONTENT_TYPE' => 'multipart/form-data; boundary="greatgoatsofgerta"'
		}
		parser = mock( "multipart parser", :null_object => true )

		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
		@mongrel_request.should_receive( :body ).once.and_return( :body )
		parser.should_receive( :parse ).once.
			with( :body, 'greatgoatsofgerta' ).
			and_return( :parsed_stuff )

		@request.parse_multipart_body.should == :parsed_stuff
	end


	it "provides a Hash for URI query arguments" do
		params = {
			'REQUEST_PATH' => '/876e30c4-56bd-11dc-88be-0016cba18fb9',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'wow%20ow%20wee%20wow=1&no-val;semicolon-val=jyes',
		}
		@mongrel_request.should_receive( :params ).
			at_least(:once).
			and_return( params )
		
		@request.uri.should be_an_instance_of( URI::HTTP )
		@request.uri.query.should_receive( :nil? ).
			once.
			and_return( false )

		args = @request.query_args
		args.should have(3).members
		args['wow ow wee wow'].should == 1
		args['no-val'].should == true
		args['semicolon-val'].should == 'jyes'
		args['nonexistent'].should == nil
	end


	it "knows what the requested URI is" do
		params = {
			'REQUEST_PATH' => '/inspect',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'king=thingwit',
		}
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )

		@request.uri.should be_an_instance_of( URI::HTTP )
		@request.uri.path.should  == '/inspect'
		@request.uri.host.should  == 'thingfish.laika.com'
		@request.uri.query.should == 'king=thingwit'
		@request.uri.port.should  == 3474
	end
    

	it "knows what the request method is" do
		params = {
			'REQUEST_METHOD' => 'GET',
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		@request.http_method.should == 'GET'
	end
	
	
	it "knows what the requesters address is" do
		params = {
			'REMOTE_ADDR' => '127.0.0.1',
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		@request.remote_addr.should be_an_instance_of( IPAddr )
		@request.remote_addr.to_s.should == '127.0.0.1'
	end


	it "knows what mimetypes are acceptable responses" do
		params = {
			'HTTP_ACCEPT' => 'text/html, text/plain; q=0.5, image/*;q=0.1',
		}
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.accepts?( 'text/html' ).should be_true()
		@request.accepts?( 'text/plain' ).should be_true()
		@request.accepts?( 'text/ascii' ).should be_false()

		@request.accepts?( 'image/png' ).should be_true()
		@request.accepts?( 'application/x-yaml' ).should be_false()
	end
	

	it "accepts anything if the client doesn't provide an Accept header" do
		params = {}
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.accepts?( 'text/html' ).should be_true()
		@request.accepts?( 'text/plain' ).should be_true()
		@request.accepts?( 'text/ascii' ).should be_true()
		@request.accepts?( 'image/png' ).should be_true()
		@request.accepts?( 'application/x-yaml' ).should be_true()
	end
	
end

# vim: set nosta noet ts=4 sw=4:
