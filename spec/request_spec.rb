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
	require 'ipaddr'
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
	
	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		@mongrel_request = mock( "mongrel request", :null_object => true )
		config = stub( "Config object", :spooldir => 'sdfgsd', :bufsize => 3 )
		@request = ThingFish::Request.new( @mongrel_request, config )
		@request.stub!( :path_info ).and_return( '/a/test/path' )
	end

	after( :all ) do
		ThingFish.reset_logger
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
	
	
	it "calls the block of the body iterator with the single body entity and merged metadata" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'application/x-bungtruck',
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		}

		# Set some keys that will collide with default and header-based value so we
		# can test merge precedence
		extracted_metadata = {
			:extent => 2,
			:useragent => 'Burritos',
		}
		body = StringIO.new( TEST_CONTENT )

		@request.metadata[ body ].update( extracted_metadata )
		@mongrel_request.should_receive( :params ).
			at_least( :once ).
			and_return( params )
		@mongrel_request.should_receive( :body ).
			at_least( :once ).
			and_return( body )

		@request.each_body do |body, metadata|
			body.should == body
			metadata.should have(4).members
			metadata[:extent].should == 11111
			metadata[:useragent].should == 'Hotdogs'
		end
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
	

	it "knows that it's not an ajax request" do
		@request.is_ajax_request?.should == false
	end
	
end

describe ThingFish::Request, " with cache headers" do

	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		@config = stub( "config object" )
		@request_headers = mock( "request headers", :null_object => true )
		@request = ThingFish::Request.new( nil, @config )
		@request.instance_variable_set( :@headers, @request_headers )
		@request.stub!( :path_info ).and_return( '/a/test/path' )
		
		@etag = %{"%s"} % [ TEST_CHECKSUM ]
		@weak_etag = %{W/"v1.2"}
	end

	
	### Cache header predicate
	
	# [RFC 2616]: If any of the entity tags match the entity tag of the
	# entity that would have been returned in the response to a similar
	# GET request (without the If-None-Match header) on that resource,
	# or if "*" is given and any current entity exists for that resource,
	# then the server MUST NOT perform the requested method, unless
	# required to do so because the resource's modification date fails
	# to match that supplied in an If-Modified-Since header field in the
	# request.

	it "checks the content cache token to see if it is cached by the client" do
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( @etag )

		@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
	end
	
	
	it "checks all cache content tokens to see if it is cached by the client" do
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( %Q{#{@weak_etag}, "#{@etag}"} )

		@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
	end
	

	it "ignores weak cache tokens when checking to see if it is cached by the client" do
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( @weak_etag )

		@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_false()
	end


	it "indicates that the client has a cached copy with a wildcard If-None-Match" do
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( '*' )

		@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
	end


	it "ignores a wildcard 'If-None-Match' if the 'If-Modified-Since' " +
	   "header is out of date when checking to see if the client has a cached copy" do

		@request_headers.should_receive( :[] ).
			with( :if_modified_since ).
			and_return( 8.days.ago.httpdate )
		@request_headers.should_receive( :[] ).
			with( :if_none_match ).
			and_return( '*' )
  
		@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_false()
	end
	
end

describe ThingFish::Request, " with a multipart body" do

	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
	
	before( :each ) do
		params = {
			'HTTP_CONTENT_TYPE'   => 'multipart/form-data; boundary="greatgoatsofgerta"',
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		}
		@mongrel_request = mock( "mongrel request", :null_object => true )
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )

		config = stub( "Config object", :spooldir => 'sdfgsd', :bufsize => 3 )

		@request = ThingFish::Request.new( @mongrel_request, config )
		@request.stub!( :path_info ).and_return( '/a/test/path' )
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	
	
	it "knows it has a multipart body" do
		@request.should have_multipart_body()
	end
	
	
	it "sends each body entity of the request and a copy of the merged metadata to " +
		"the block of the body iterator" do
		io1 = mock( "filehandle 1" )
		io2 = mock( "filehandle 2" )

		parser = mock( "multipart parser", :null_object => true )
		entity_bodies = {
			io1 => {:title  => "filename1",:format => "format1",:extent => 100292},
			io2 => {:title  => "filename2",:format => "format2",:extent => 100234}
		  }
		form_metadata = {
			'foo' => 1,
			:title => "a bogus filename",
			:useragent => 'Clumpy the Clown',
		  }
		extracted_metadata = {
			io1 => { :format => "a bogus format" },
			io2 => { :format => "another bogus format" },
		  }

		io1.should_receive( :closed? ).and_return( true )
		io1.should_receive( :open )
		io2.should_receive( :closed? ).and_return( true )
		io2.should_receive( :open )

		ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
		@mongrel_request.should_receive( :body ).once.and_return( :body )
		parser.should_receive( :parse ).once.
			with( :body, 'greatgoatsofgerta' ).
			and_return([ entity_bodies, form_metadata ])
		
		yielded_pairs = {}
		@request.each_body do |body, parsed_metadata|
			yielded_pairs[ body ] = parsed_metadata
		end
		
		yielded_pairs.keys.should have(2).members
		yielded_pairs.keys.should include( io1 )
		yielded_pairs.keys.should include( io2 )

		yielded_pairs[ io1 ][ :title ].should == 'filename1'
		yielded_pairs[ io1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )
		yielded_pairs[ io2 ][ :title ].should == 'filename2'
		yielded_pairs[ io2 ][ :format ].should == "format2"
		yielded_pairs[ io2 ][ :useragent ].should == "Hotdogs"
		yielded_pairs[ io2 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )	
	end
	
end

describe ThingFish::Request, " sent via XMLHTTPRequest" do
	before( :each ) do
		@config = stub( "config object" )
		@request_headers = mock( "request headers", :null_object => true )
		@request = ThingFish::Request.new( nil, @config )
		@request.instance_variable_set( :@headers, @request_headers )
		@request.stub!( :path_info ).and_return( '/a/test/path' )
		@request_headers.should_receive( :[] ).
			at_least( :once ).
			with( :x_requested_with ).
			and_return( 'XmlHttpRequest' )
	end
	
	it "knows that it's an ajax request" do
		@request.is_ajax_request?.should == true
	end
end


# vim: set nosta noet ts=4 sw=4:
