#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	
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
	include ThingFish::SpecHelpers
	
	TEMPFILE_PATH = '/var/folders/k7/k7DNYX+ZGSOBod3-pJ-Lhk++0+I/-Tmp-/thingfish.65069.0'
	
	before(:all) do
		setup_logging( :fatal )
	end
	
	before( :each ) do
		@mongrel_request = mock( "mongrel request", :null_object => true )
		@config = stub( "Config object" )
		@default_params = {
			'SERVER_NAME'	=> 'thingfish.laika.com',
			'SERVER_PORT'	=> '3474',
			'REQUEST_PATH'	=> '/',
			'QUERY_STRING'	=> '',
		}
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	
	it "wraps and delegates requests for the body to the mongrel request's body " +
	   "if we haven't replaced it" do
		@mongrel_request.stub!( :params ).and_return( @default_params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		@mongrel_request.should_receive( :body ).and_return( :the_body )
		request.body.should == :the_body
	end
	
	
	it "returns the new body if the body has been replaced" do
		@mongrel_request.stub!( :params ).and_return( @default_params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.body = :new_body
		@mongrel_request.should_not_receive( :body )
		request.body.should == :new_body
	end
	
	
	it "knows how to return the original body even if the body has been replaced" do
		@mongrel_request.stub!( :params ).and_return( @default_params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.body = :new_body
		@mongrel_request.should_receive( :body ).and_return( :original_body )
		request.original_body.should == :original_body
	end
	
	
	it "extracts HTTP headers as simple headers from its mongrel request" do
		params = @default_params.merge({
			'HTTP_ACCEPT' => 'Accept',
		})
		
		@mongrel_request.stub!( :params ).and_return( params )

		request = ThingFish::Request.new( @mongrel_request, @config )		
		request.headers['accept'].should == 'Accept'
		request.headers['Accept'].should == 'Accept'
		request.headers['ACCEPT'].should == 'Accept'
	end
	
	
	it "parses the 'Accept' header into one or more AcceptParam structs" do
		params = @default_params.merge({	
			# 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'
			'HTTP_ACCEPT' => TEST_ACCEPT_HEADER,
		})
		
		@mongrel_request.stub!( :params ).and_return( params )
		
		request = ThingFish::Request.new( @mongrel_request, @config )
		request.accepted_types.should have(3).members
		request.accepted_types[0].mediatype.should == 'application/x-yaml'
		request.accepted_types[1].mediatype.should == 'application/json'
		request.accepted_types[2].mediatype.should == 'text/xml'
	end
	
	it "knows when it does not have a multipart/form-data body" do
		params = @default_params.merge({
			'Content-type' => 'application/x-bungtruck'
		})

		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		request.should_not have_multipart_body()
	end
	
	
	it "calls the block of the body iterator with the single body entity and merged metadata" do
		params = @default_params.merge({
			'HTTP_CONTENT_TYPE'   => 'application/x-bungtruck',
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )

		# Set some keys that will collide with default and header-based value so we
		# can test merge precedence
		extracted_metadata = {
			:extent => 2,
			:useragent => 'Burritos',
		}
		body = StringIO.new( TEST_CONTENT )

		request.metadata[ body ].update( extracted_metadata )
		@mongrel_request.should_receive( :body ).
			at_least( :once ).
			and_return( body )

		request.each_body do |body, metadata|
			body.should == body
			metadata.should have(4).members
			metadata[:extent].should == 11111
			metadata[:useragent].should == 'Hotdogs'
		end
	end
	
	
	it "allows new metadata to be appended to resources yielded from the iterator" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'image/x-bitmap',
			'HTTP_CONTENT_LENGTH' => 18181,
			'HTTP_USER_AGENT'     => 'GarglePants/1.0',
			'REMOTE_ADDR'         => '127.0.0.1',
		}
		upload = StringIO.new( TEST_CONTENT )
		@mongrel_request.stub!( :params ).and_return( params )
		@mongrel_request.stub!( :body ).and_return( upload )
		request = ThingFish::Request.new( @mongrel_request, @config )

		request.each_body do |body, metadata|
			metadata = { 'relation' => 'thumbnail' }
			request.append_metadata_for( body, metadata )
		end

		request.metadata.should have_key( upload )
		request.metadata[ upload ].should have(1).member
		request.metadata[ upload ][ 'relation' ].should == 'thumbnail'
	end
	
	
	it "allows appending of resources related to the ones in the entity body (StringIO)" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'application/x-bungtruck',
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		}
		upload = StringIO.new( TEST_CONTENT )
		@mongrel_request.stub!( :params ).and_return( params )
		@mongrel_request.stub!( :body ).and_return( upload )
		request = ThingFish::Request.new( @mongrel_request, @config )

		generated_resource = StringIO.new( "generated content" )
		metadata = { 'relation' => 'thumbnail' }

		request.each_body do |body, metadata|
			request.append_related_resource( body, generated_resource, metadata )
		end

		request.related_resources.should have_key( upload )
		request.related_resources[ upload ].should be_an_instance_of( Hash )
		request.related_resources[ upload ].should have(1).member
		request.related_resources[ upload ].keys.should == [ generated_resource ]
		request.related_resources[ upload ].values.should == [ metadata ]
	end


	it "allows appending of resources related to the ones in the entity body (Tempfile)" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'application/x-bungtruck',
			'HTTP_CONTENT_LENGTH' => 37337,
			'HTTP_USER_AGENT'     => 'Plantains',
			'REMOTE_ADDR'         => '18.17.16.15',
		}

		upload = mock( "Mock Upload Tempfile" )
		@mongrel_request.stub!( :params ).and_return( params )
		@mongrel_request.stub!( :body ).and_return( upload )
		request = ThingFish::Request.new( @mongrel_request, @config )

		generated_resource = StringIO.new( "generated content" )
		metadata = { 'relation' => 'thumbnail' }

		request.each_body do |body, metadata|
			request.append_related_resource( body, generated_resource, metadata )
		end

		request.related_resources.should have_key( upload )
		request.related_resources[ upload ].should be_an_instance_of( Hash )
		request.related_resources[ upload ].should have(1).member
		request.related_resources[ upload ].keys.should == [ generated_resource ]
		request.related_resources[ upload ].values.should == [ metadata ]
	end


	it "allows appending of resources related to already-appended ones" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'application/x-gungtruck',
			'HTTP_CONTENT_LENGTH' => 121212,
			'HTTP_USER_AGENT'     => 'Sausages',
			'REMOTE_ADDR'         => '127.0.0.1',
		}

		upload = StringIO.new( TEST_CONTENT )
		
		@mongrel_request.stub!( :params ).and_return( params )
		@mongrel_request.stub!( :body ).and_return( upload )
		request = ThingFish::Request.new( @mongrel_request, @config )

		generated_resource = StringIO.new( "generated content" )
		metadata = { 'relation' => 'part_of' }
		sub_generated_resource = StringIO.new( "content generated from the generated content" )
		sub_metadata = { 'relation' => 'thumbnail' }

		request.each_body do |body, metadata|
			request.append_related_resource( body, generated_resource, metadata )
			ThingFish.logger.debug "Request related resources is now: %p" % [ request.related_resources ]
			request.append_related_resource( generated_resource, sub_generated_resource, sub_metadata )
		end

		request.related_resources.should have_key( upload )
		request.related_resources[ upload ].should be_an_instance_of( Hash )
		request.related_resources[ upload ].should have(1).member
		request.related_resources[ upload ].keys.should == [ generated_resource ]
		request.related_resources[ upload ].values.should == [ metadata ]
		request.related_resources.should have_key( generated_resource )
		request.related_resources[ generated_resource ].should be_an_instance_of( Hash )
		request.related_resources[ generated_resource ].should have(1).member
		request.related_resources[ generated_resource ].keys.should == [ sub_generated_resource ]
		request.related_resources[ generated_resource ].values.should == [ sub_metadata ]
	end


	it "requires 'related' resources be appended with a body that's part of the request" do
		params = {
			'HTTP_CONTENT_TYPE'   => 'application/x-bungtruck',
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		}

		upload = StringIO.new( TEST_CONTENT )
		@mongrel_request.stub!( :params ).and_return( params )
		@mongrel_request.stub!( :body ).and_return( upload )
		request = ThingFish::Request.new( @mongrel_request, @config )


		mystery_resource = StringIO.new( "mystery content" )
		generated_resource = StringIO.new( "generated content" )
		metadata = { 'relation' => 'thumbnail' }

		lambda { 
			request.each_body do |body, _|
				request.append_related_resource( mystery_resource, generated_resource, metadata )
			end
		}.should raise_error( ThingFish::ResourceError, /cannot append/i )
	end
	
	
	it "ensures a valid content-type is set if none is provided" do
		params = @default_params.merge({
			'HTTP_CONTENT_LENGTH' => 11111,
			'HTTP_USER_AGENT'     => 'Hotdogs',
			'REMOTE_ADDR'         => '127.0.0.1',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )

		# Set some keys that will collide with default and header-based value so we
		# can test merge precedence
		extracted_metadata = {
			:extent => 2,
			:useragent => 'Burritos',
		}
		body = StringIO.new( TEST_CONTENT )


		request.metadata[ body ].update( extracted_metadata )
		@mongrel_request.should_receive( :params ).
			at_least( :once ).
			and_return( params )
		@mongrel_request.should_receive( :body ).
			at_least( :once ).
			and_return( body )

		request.each_body do |body, metadata|
			body.should == body
			metadata.should have(4).members
			metadata[:extent].should == 11111
			metadata[:useragent].should == 'Hotdogs'
			metadata[:format] == DEFAULT_CONTENT_TYPE
		end
	end
	
	
	it "provides a Hash for URI query arguments" do
		params = @default_params.merge({
			'REQUEST_PATH' => '/search',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'wow%20ow%20wee%20wow=1&no-val;semicolon-val=jyes',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.uri.should be_an_instance_of( URI::HTTP )
		request.uri.query.should_receive( :nil? ).
			once.
			and_return( false )

		args = request.query_args
		args.should have(3).members
		args['wow ow wee wow'].should == 1
		args['no-val'].should be_nil()
		args['semicolon-val'].should == 'jyes'
		args.has_key?('nonexistent').should == false
	end


	it "query arguments that appear more than once are put in an Array" do
		params = @default_params.merge({
			'REQUEST_PATH' => '/search',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'format=image/jpeg;format=image/png;format=image/gif',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.uri.should be_an_instance_of( URI::HTTP )
		request.uri.query.should_receive( :nil? ).
			once.
			and_return( false )

		args = request.query_args
		args.should have(1).members
		args['format'].should be_an_instance_of( Array )
		args['format'].should have(3).members
		args['format'].should include('image/jpeg')
		args['format'].should include('image/png')
		args['format'].should include('image/gif')
	end


	it "detects when profiling is requested" do
		params = @default_params.merge({
			'QUERY_STRING' => 'wow%20ow%20wee%20wow=1&_profile=true&no-val;semicolon-val=jyes',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.uri.should be_an_instance_of( URI::HTTP )

		args = request.query_args
		request.run_profile?.should == true
		args.should_not include('_profile')
	end


	it "knows what the requested URI is" do
		params = @default_params.merge({
			'REQUEST_PATH' => '/inspect',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'king=thingwit',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )

		request.uri.should be_an_instance_of( URI::HTTP )
		request.uri.path.should  == '/inspect'
		request.uri.host.should  == 'thingfish.laika.com'
		request.uri.query.should == 'king=thingwit'
		request.uri.port.should  == 3474
	end
    

	it "knows what the request method is" do
		params = @default_params.merge({
			'REQUEST_METHOD' => 'GET',
		})
		
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.http_method.should == 'GET'
	end
	
	
	it "knows what the request path is" do
		params = @default_params.merge({
			'REQUEST_PATH' => '/anti/pasta',
			'SERVER_NAME' => 'thingfish.laika.com',
			'SERVER_PORT' => '3474',
			'QUERY_STRING' => 'king=thingwit',
		})
		
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.path.should == '/anti/pasta'
	end
	
	
	it "knows what the requesters address is" do
		params = @default_params.merge({
			'REMOTE_ADDR' => '127.0.0.1',
		})
		
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.remote_addr.should be_an_instance_of( IPAddr )
		request.remote_addr.to_s.should == '127.0.0.1'
	end


	it "knows what the request content type is" do
		params = @default_params.merge({
			'HTTP_CONTENT_TYPE' => 'text/erotica',
		})
		
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.content_type.should == 'text/erotica'
	end

	
	it "can modify the request content type" do
		params = @default_params.merge({
			'HTTP_CONTENT_TYPE' => 'text/erotica',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.content_type = 'image/nude'
		request.content_type.should == 'image/nude'
	end
	
	
	it "knows what mimetypes are acceptable responses" do
		params = @default_params.merge({
			'HTTP_ACCEPT' => 'text/html, text/plain; q=0.5, image/*;q=0.1',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.accepts?( 'text/html' ).should be_true()
		request.accepts?( 'text/plain' ).should be_true()
		request.accepts?( 'text/ascii' ).should be_false()

		request.accepts?( 'image/png' ).should be_true()
		request.accepts?( 'application/x-yaml' ).should be_false()
	end


	it "knows what mimetypes are explicitly acceptable responses" do
		params = @default_params.merge({
			'HTTP_ACCEPT' => 'text/html, text/plain; q=0.5, image/*;q=0.1, */*',
		})
		@mongrel_request.stub!( :params ).and_return( params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.explicitly_accepts?( 'text/html' ).should be_true()
		request.explicitly_accepts?( 'text/plain' ).should be_true()
		request.explicitly_accepts?( 'text/ascii' ).should be_false()

		request.explicitly_accepts?( 'image/png' ).should be_false()
		request.explicitly_accepts?( 'application/x-yaml' ).should be_false()
	end
		

	it "accepts anything if the client doesn't provide an Accept header" do
		@mongrel_request.stub!( :params ).and_return( @default_params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.accepts?( 'text/html' ).should be_true()
		request.accepts?( 'text/plain' ).should be_true()
		request.accepts?( 'text/ascii' ).should be_true()
		request.accepts?( 'image/png' ).should be_true()
		request.accepts?( 'application/x-yaml' ).should be_true()
	end
	

	it "knows that it's not an ajax request" do
		@mongrel_request.stub!( :params ).and_return( @default_params )
		request = ThingFish::Request.new( @mongrel_request, @config )
		
		request.is_ajax_request?.should == false
	end
	

	describe " with cache headers" do

		before( :each ) do
			@config = stub( "config object" )
			mongrel_request = mock( "mongrel request", :null_object => true )
			mongrel_request.stub!( :params ).and_return({
				'SERVER_NAME'	=> 'thingfish.laika.com',
				'SERVER_PORT'	=> '3474',
				'REQUEST_PATH'	=> '/',
				'QUERY_STRING'	=> '',
			})
			@request_headers = mock( "request headers", :null_object => true )

			@request = ThingFish::Request.new( mongrel_request, @config )
			@request.instance_variable_set( :@headers, @request_headers )
		
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

	describe " with a multipart body" do

		before( :each ) do
			params = {
				'HTTP_CONTENT_TYPE'   => 'multipart/form-data; boundary="greatgoatsofgerta"',
				'HTTP_CONTENT_LENGTH' => 11111,
				'HTTP_USER_AGENT'     => 'Hotdogs',
				'REMOTE_ADDR'         => '127.0.0.1',
				'SERVER_NAME'         => 'thingfish.laika.com',
				'SERVER_PORT'         => '3474',
				'REQUEST_PATH'        => '/',
				'QUERY_STRING'        => '',
			}
			@mongrel_request = mock( "mongrel request", :null_object => true )
			@mongrel_request.stub!( :params ).and_return( params )

			config = stub( "Config object", :spooldir_path => Pathname.new('asdfsadf'), :bufsize => 3 )

			@request = ThingFish::Request.new( @mongrel_request, config )
			@request.stub!( :path_info ).and_return( '/a/test/path' )
		end

	
		it "knows it has a multipart body" do
			@request.should have_multipart_body()
		end
	
	
		it "sends IO bodies as well as appended resources with merged metadata to the block " +
		   "of the resource iterator" do
			io1 = mock( "filehandle 1" )
			io2 = mock( "filehandle 2" )

			resource1 = mock( "extracted body 1" )

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

			ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
			@mongrel_request.should_receive( :body ).once.and_return( :body )
			parser.should_receive( :parse ).once.
				with( :body, 'greatgoatsofgerta' ).
				and_return([ entity_bodies, form_metadata ])

			yielded_pairs = {}
			@request.each_body( true ) do |res, parsed_metadata|
				if res == io1
					thumb_metadata = {
						:relation => 'thumbnail',
						:format   => 'image/jpeg',
						:title    => 'filename1_thumb.jpg',
					  }
					@request.append_related_resource( io1, resource1, thumb_metadata )
				end
					
				yielded_pairs[ res ] = parsed_metadata
			end

			yielded_pairs.keys.should have(3).members
			yielded_pairs.keys.should include( io1, io2, resource1 )

			yielded_pairs[ io1 ][ :title ].should == 'filename1'
			yielded_pairs[ io1 ][ :format ].should == 'format1'
			yielded_pairs[ io1 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ io1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )

			yielded_pairs[ io2 ][ :title ].should == 'filename2'
			yielded_pairs[ io2 ][ :format ].should == "format2"
			yielded_pairs[ io2 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ io2 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )	

			yielded_pairs[ resource1 ][ :title ].should == 'filename1_thumb.jpg'
			yielded_pairs[ resource1 ][ :format ].should == 'image/jpeg'
			yielded_pairs[ resource1 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ resource1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )	
		end
	
		it "sends each IO body entity of the request and a copy of the merged metadata to " +
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
			yielded_pairs.keys.should include( io1, io2 )

			yielded_pairs[ io1 ][ :title ].should == 'filename1'
			yielded_pairs[ io1 ][ :format ].should == 'format1'
			yielded_pairs[ io1 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ io1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )

			yielded_pairs[ io2 ][ :title ].should == 'filename2'
			yielded_pairs[ io2 ][ :format ].should == "format2"
			yielded_pairs[ io2 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ io2 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )	
		end
	

		it "ensures each part sent to the body has the default content-type " +
		   "if none is explicitly provided by the request" do
			io1 = mock( "filehandle 1" )
			io2 = mock( "filehandle 2" )

			parser = mock( "multipart parser", :null_object => true )
			entity_bodies = {
				io1 => {:title  => "filename1", :extent => 100292},
				io2 => {:title  => "filename2", :extent => 100234}
			  }
			form_metadata = {
				'foo' => 1,
				:title => "a bogus filename",
				:useragent => 'Clumpy the Clown',
			  }

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
			yielded_pairs.keys.should include( io1, io2 )

			yielded_pairs[ io1 ][ :title ].should == 'filename1'
			yielded_pairs[ io1 ][ :format ].should == DEFAULT_CONTENT_TYPE
			yielded_pairs[ io1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )
			yielded_pairs[ io2 ][ :title ].should == 'filename2'
			yielded_pairs[ io2 ][ :format ].should == DEFAULT_CONTENT_TYPE
			yielded_pairs[ io2 ][ :useragent ].should == "Hotdogs"
			yielded_pairs[ io2 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )	
		end
	
	end

	describe " sent via XMLHTTPRequest" do
		before( :each ) do
			params = {
				'HTTP_CONTENT_TYPE'   => 'multipart/form-data; boundary="greatgoatsofgerta"',
				'HTTP_CONTENT_LENGTH' => 11111,
				'HTTP_USER_AGENT'     => 'Hotdogs',
				'REMOTE_ADDR'         => '127.0.0.1',
				'SERVER_NAME'         => 'thingfish.laika.com',
				'SERVER_PORT'         => '3474',
				'REQUEST_PATH'        => '/',
				'QUERY_STRING'        => '',
			}
			mongrel_request = mock( "mongrel request", :null_object => true )
			mongrel_request.stub!( :params ).and_return( params )

			@config = stub( "config object" )
			@request_headers = mock( "request headers", :null_object => true )
			@request = ThingFish::Request.new( mongrel_request, @config )
			@request.instance_variable_set( :@headers, @request_headers )
			@request_headers.should_receive( :[] ).
				at_least( :once ).
				with( :x_requested_with ).
				and_return( 'XmlHttpRequest' )
		end
	
		it "knows that it's an ajax request" do
			@request.is_ajax_request?.should == true
		end
	end

end


# vim: set nosta noet ts=4 sw=4:
