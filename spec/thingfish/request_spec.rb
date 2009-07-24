#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'ipaddr'
	require 'thingfish'
	require 'thingfish/config'
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
include ThingFish::Constants::Patterns

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Request do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
		@config = ThingFish::Config.new
		@socket = mock( "request socket" )
		@socket.stub!( :peeraddr ).and_return( ["AF_INET", 22, "localhost", "127.0.0.1"] )
	end

	after( :all ) do
		reset_logging()
	end


	# Header:
	#   value
	it "handles headers with values that begin after CRLF + indentation" do
		data = TESTING_GET_REQUEST.
			sub( /Host: localhost:3474/, "Host:#{CRLF}  localhost:3474" )

		req = ThingFish::Request.parse( data, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :GET
		req.header[:host].should == 'localhost:3474'
	end

	# Header:
	#
	#   value
	it "handles headers with values that begin after blank indented lines" do
		data = TESTING_GET_REQUEST.
			sub( /Host: localhost:3474/, "Host:#{CRLF}  #{CRLF}  localhost:3474" )

		req = ThingFish::Request.parse( data, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :GET
		req.header[:host].should == 'localhost:3474'
	end

	# Header:value
	it "handles headers that have no leading whitespace" do
		data = TESTING_GET_REQUEST.
			sub( /Host: localhost:3474/, "Host:localhost:3474" )

		req = ThingFish::Request.parse( data, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :GET
		req.header[:host].should == 'localhost:3474'
	end


	it "parses a valid GET request" do
		req = ThingFish::Request.parse( TESTING_GET_REQUEST, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :GET
		req.header[:keep_alive].should == '300'
		req.header[:accept_encoding].should == 'gzip,deflate'
		req.header[:user_agent].should ==
			'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; ' +
			'rv:1.9.0.1) Gecko/2008070206 Firefox/3.0.1'
	end


	it "parses a valid POST request" do
		header = TESTING_POST_REQUEST.split( EOL + EOL, 2 ).first
		header << EOL + EOL
		req = ThingFish::Request.parse( header, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :POST
	end


	it "parses a valid DELETE request" do
		req = ThingFish::Request.parse( TESTING_DELETE_REQUEST, @config, @socket )

		req.should be_an_instance_of( ThingFish::Request )
		req.http_method.should == :DELETE
	end


	it "raises a RequestError if the data is not a valid HTTP request" do
		lambda {
			ThingFish::Request.parse( "this is so not a request", @config, @socket )
		}.should raise_error( ThingFish::RequestError, /malformed request/i )
	end


	describe "instance for a GET" do

		before( :each ) do
			@config = ThingFish::Config.new
			@request = ThingFish::Request.parse( TESTING_GET_REQUEST, @config, @socket )
		end

		it "parses the 'Accept' header into one or more AcceptParam structs" do
			@request.headers.should_receive( :[] ).with( :accept ).
				and_return( TEST_ACCEPT_HEADER )

			@request.accepted_types.should have(3).members
			@request.accepted_types[0].mediatype.should == 'application/x-yaml'
			@request.accepted_types[1].mediatype.should == 'application/json'
			@request.accepted_types[2].mediatype.should == 'text/xml'
		end


		it "knows when it does not have a multipart/form-data body" do
			@request.headers.should_receive( :[] ).with( :content_type ).at_least( :once ).
				and_return( 'application/x-bungtruck' )
			@request.should_not have_multipart_body()
		end


		it "doesn't yield the non-existant body" do
			count = 0
			@request.each_body do |_, _|
				count += 1
			end
			count.should == 0
		end


		it "provides a Hash for URI query arguments" do
			uri = URI.parse( '/search?wow%20ow%20wee%20wow=1&no-val;semicolon-val=jyes' )
			@request.instance_variable_set( :@uri, uri )

			args = @request.query_args
			args.should have(3).members
			args['wow ow wee wow'].should == 1
			args['no-val'].should be_nil()
			args['semicolon-val'].should == 'jyes'
			args.has_key?('nonexistent').should == false
		end


		it "query arguments that appear more than once are put in an Array" do
			uri = URI.parse( '/search?format=image/jpeg;format=image/png;format=image/gif' )
			@request.instance_variable_set( :@uri, uri )

			args = @request.query_args
			args.should have(1).members
			args['format'].should be_an_instance_of( Array )
			args['format'].should have(3).members
			args['format'].should include('image/jpeg')
			args['format'].should include('image/png')
			args['format'].should include('image/gif')
		end


		it "detects when profiling is requested via query args" do
			headers = ThingFish::Table.new
			uri = URI.parse( '/?wow%20ow%20wee%20wow=1&_profile=true&no-val;semicolon-val=jyes' )
			request = ThingFish::Request.new( @socket, :GET, uri, '1.1', headers, @config )

			args = request.query_args
			request.run_profile?.should == true
			args.keys.should_not include( '_profile' )
		end


		it "detects when profiling is requested via a cookie"


		it "knows what the request method is" do
			@request.http_method.should == :GET
		end


		it "knows what the request path is" do
			@request.path.should == '/'
		end


		it "knows what the requesters address is" do
			@request.remote_addr.should be_an_instance_of( IPAddr )
			@request.remote_addr.to_s.should == '127.0.0.1'
		end


		it "knows what the request content type is" do
			@request.headers[ 'Content-Type' ] = 'text/erotica'
			@request.headers[ :content_type ].should == 'text/erotica'
			@request.content_type.should == 'text/erotica'
		end


		it "can modify the request content type" do
			@request.content_type = 'image/nude'
			@request.content_type.should == 'image/nude'
		end


		it "knows what mimetypes are acceptable responses" do
			@request.headers[ :accept ] = 'text/html, text/plain; q=0.5, image/*;q=0.1'

			@request.accepts?( 'text/html' ).should be_true()
			@request.accepts?( 'text/plain' ).should be_true()
			@request.accepts?( 'text/ascii' ).should be_false()
			@request.accepts?( 'image/png' ).should be_true()
			@request.accepts?( 'application/x-yaml' ).should be_false()
		end


		it "knows what mimetypes are explicitly acceptable responses" do
			@request.header[ :accept ] = 'text/html, text/plain; q=0.5, image/*;q=0.1, */*'

			@request.explicitly_accepts?( 'text/html' ).should be_true()
			@request.explicitly_accepts?( 'text/plain' ).should be_true()
			@request.explicitly_accepts?( 'text/ascii' ).should be_false()
			@request.explicitly_accepts?( 'image/png' ).should be_false()
			@request.explicitly_accepts?( 'application/x-yaml' ).should be_false()
		end


		it "accepts anything if the client doesn't provide an Accept header" do
			@request.accepts?( 'text/html' ).should be_true()
			@request.accepts?( 'text/plain' ).should be_true()
			@request.accepts?( 'text/ascii' ).should be_true()
			@request.accepts?( 'image/png' ).should be_true()
			@request.accepts?( 'application/x-yaml' ).should be_true()
		end


		it "knows that it's not an ajax request" do
			@request.should_not be_an_ajax_request()
		end
		
		
		it "knows it's not a pipelined request" do
			@request.should_not be_keepalive()
		end
	end

	describe "instance with a POST request" do

		before( :all ) do
			setup_logging( :fatal )
		end

		after( :all ) do
			reset_logging()
		end

		before( :each ) do
			@config = ThingFish::Config.new
			header = TESTING_POST_REQUEST.split( EOL + EOL, 2 ).first
			header << EOL + EOL

			@request = ThingFish::Request.parse( header, @config, @socket )
			
			@etag = %{"%s"} % [ TEST_CHECKSUM ]
			@weak_etag = %{W/"v1.2"}
		end


		### Body IO checks

		it "doesn't perform any checks if there isn't a body" do
			@request.instance_variable_set( :@entity_bodies, { nil => {} } )
			lambda {
				@request.check_body_ios				
			}.should_not raise_error()
		end
		
		
		it "can sanity-check the IO objects that contain entity body data for EOF state" do
			io = mock( "Entity body IO" )

			@request.instance_variable_set( :@entity_bodies, { io => {} } )
			@request.instance_variable_set( :@form_metadata, {} )

			io.should_receive( :closed? ).and_return( false )
			io.should_receive( :rewind )

			@request.check_body_ios
		end


		it "can replace a File IO object that contains entity body data if it becomes closed" do
			io = mock( "Entity body File IO" )
			clone_io = mock( "Cloned entity body File IO" )
			@request.instance_variable_set( :@entity_bodies, { io => {} } )
			@request.instance_variable_set( :@form_metadata, {} )

			io.should_receive( :closed? ).and_return( true )
			io.should_receive( :is_a? ).with( StringIO ).and_return( false )
			io.should_receive( :path ).and_return( :filepath )
			File.should_receive( :open ).with( :filepath, 'r' ).and_return( clone_io )

			@request.check_body_ios

			@request.instance_variable_get( :@entity_bodies ).should_not have_key( io )
			@request.metadata.should_not have_key( io )
			@request.instance_variable_get( :@entity_bodies ).should have_key( clone_io )
			@request.metadata.should have_key( clone_io )
		end


		it "can replace a StringIO object that contains entity body data if it becomes closed" do
			io = mock( "Entity body StringIO" )
			clone_io = mock( "Cloned entity body StringIO" )
			@request.instance_variable_set( :@entity_bodies, { io => {} } )
			@request.instance_variable_set( :@form_metadata, {} )

			io.should_receive( :closed? ).and_return( true )
			io.should_receive( :is_a? ).with( StringIO ).and_return( true )
			io.should_receive( :string ).and_return( :stringdata )
			StringIO.should_receive( :new ).with( :stringdata ).and_return( clone_io )

			# clone_io.should_receive( :closed? ).and_return( false )
			# clone_io.should_receive( :rewind )

			@request.check_body_ios
		end


		it "calls the block of the body iterator with the single body entity and merged metadata" do
			@request.headers.merge!(
				'content-type'   => 'application/x-bungtruck',
				'content-length' => 11111,
				'user-agent'     => 'Hotdogs'
			)

			# Set some keys that will collide with default and header-based value so we
			# can test merge precedence
			extracted_metadata = {
				:extent    => 2,
				:useragent => 'Burritos',
			}

			body = mock( "request body" )
			@request.body = body
			@request.metadata[ body ].update( extracted_metadata )

			@request.each_body do |eached_body, metadata|
				eached_body.hash.should == body.hash
				metadata.should have(4).members
				metadata[:extent].should == 11111
				metadata[:useragent].should == 'Hotdogs'
			end
		end


		it "allows new metadata to be appended to resources yielded from the iterator" do
			@request.headers.merge!(
				'Content-Type'   => 'image/x-bitmap',
				'Content-Length' => 18181,
				'User-Agent'     => 'GarglePants/1.0'
			)

			body = mock( "request body" )
			@request.body = body

			@request.each_body do |eached_body, metadata|
				metadata = { 'relation' => 'thumbnail' }
				@request.append_metadata_for( eached_body, metadata )
			end

			@request.metadata.should have_key( body )
			@request.metadata[ body ].should have(1).member
			@request.metadata[ body ][ 'relation' ].should == 'thumbnail'
		end


		it "requires appended metadata to be associated with a body that's part of the request" do
			@request.headers.merge!({
				'Content-Type'    => 'image/x-bitmap',
				'Content-Length'  => 18181,
				'User-Agent'      => 'GarglePants/1.0',
			})

			body = mock( "request body" )
			@request.body = body
			
			mystery_resource = StringIO.new( "mystery content" )

			lambda {
				@request.each_body do |body, _|
					metadata = { 'relation' => 'thumbnail' }
					@request.append_metadata_for( mystery_resource, metadata )
				end
			}.should raise_error( ThingFish::ResourceError, /cannot append/i )
		end


		it "allows appending of resources related to the ones in the entity body" do
			@request.headers.merge!({
				'Content-Type'   => 'application/x-bungtruck',
				'Content-Length' => 37337,
				'User-Agent'     => 'Plantains'
			})

			body = mock( "request body" )
			@request.body = body

			generated_resource = StringIO.new( "generated content" )
			appended_metadata = { 'relation' => 'thumbnail' }

			@request.each_body do |eached_body, metadata|
				@request.append_related_resource( eached_body, generated_resource, appended_metadata )
			end

			@request.related_resources.should have_key( body )
			@request.related_resources[ body ].should be_an_instance_of( Hash )
			@request.related_resources[ body ].should have(1).member
			@request.related_resources[ body ].keys.should == [ generated_resource ]
			@request.related_resources[ body ].values.should == [ appended_metadata ]
		end


		it "allows appending of resources related to already-appended ones" do
			@request.headers.merge!({
				'Content-Type'   => 'application/x-gungtruck',
				'Content-Length' => 121212,
				'User-Agent'     => 'Sausages',
			})

			body = mock( "request body" )
			@request.body = body

			generated_resource = StringIO.new( "generated content" )
			appended_metadata = { 'relation' => 'part_of' }
			sub_generated_resource = StringIO.new( "content generated from the generated content" )
			sub_metadata = { 'relation' => 'thumbnail' }

			@request.each_body do |eached_body, metadata|
				@request.append_related_resource( eached_body, generated_resource, appended_metadata )
				ThingFish.logger.debug "Request related resources is now: %p" % [ @request.related_resources ]
				@request.append_related_resource( generated_resource, sub_generated_resource, sub_metadata )
			end

			@request.related_resources.should have_key( body )
			@request.related_resources[ body ].should be_an_instance_of( Hash )
			@request.related_resources[ body ].should have(1).member
			@request.related_resources[ body ].keys.should == [ generated_resource ]
			@request.related_resources[ body ].values.should == [ appended_metadata ]
			@request.related_resources.should have_key( generated_resource )
			@request.related_resources[ generated_resource ].should be_an_instance_of( Hash )
			@request.related_resources[ generated_resource ].should have(1).member
			@request.related_resources[ generated_resource ].keys.should == [ sub_generated_resource ]
			@request.related_resources[ generated_resource ].values.should == [ sub_metadata ]
		end


		it "requires 'related' resources be appended with a body that's part of the request" do
			@request.headers.merge!({
				'Content-Type'   => 'application/x-bungtruck',
				'Content-Length' => 11111,
				'User-Agent'     => 'Hotdogs',
			})

			body = mock( "request body" )
			@request.body = body

			mystery_resource = StringIO.new( "mystery content" )
			generated_resource = StringIO.new( "generated content" )
			metadata = { 'relation' => 'thumbnail' }

			lambda {
				@request.each_body do |_, _|
					@request.append_related_resource( mystery_resource, generated_resource, metadata )
				end
			}.should raise_error( ThingFish::ResourceError, /cannot append/i )
		end


		it "ensures a valid content-type is set if none is provided" do
			@request.headers.merge!({
				'Content-Length' => 11111,
				'User-Agent'     => 'Hotdogs',
			})

			body = mock( "request body" )
			@request.body = body

			# Set some keys that will collide with default and header-based value so we
			# can test merge precedence
			extracted_metadata = {
				:extent    => 2,
				:useragent => 'Burritos',
			}

			@request.metadata[ body ].update( extracted_metadata )
			@request.each_body do |eached_body, metadata|
				eached_body.hash.should == body.hash
				metadata.should have(4).members
				metadata[:extent].should == 11111
				metadata[:useragent].should == 'Hotdogs'
				metadata[:format] == DEFAULT_CONTENT_TYPE
			end
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
			@request.headers[:if_none_match] = @etag
			@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
		end


		it "checks all cache content tokens to see if it is cached by the client" do
			@request.headers[ :if_none_match ] = %Q{#{@weak_etag}, "#{@etag}"}
			@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
		end


		it "ignores weak cache tokens when checking to see if it is cached by the client" do
			@request.headers[:if_none_match] = @weak_etag
			@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_false()
		end


		it "indicates that the client has a cached copy with a wildcard If-None-Match" do
			@request.headers[:if_none_match] = '*'
			@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_true()
		end


		it "ignores a wildcard 'If-None-Match' if the 'If-Modified-Since' " +
		   "header is out of date when checking to see if the client has a cached copy" do
			@request.headers[:if_modified_since] = 8.days.ago.httpdate
			@request.headers[:if_none_match] = '*'
			@request.is_cached_by_client?( TEST_CHECKSUM, 3.days.ago ).should be_false()
		end

		describe " with a multipart body" do

			before( :all ) do
				setup_logging( :fatal )
			end

			before( :each ) do
				@request_body = mock( "body IO" )
				@request_body.stub!( :read ).and_return( nil )
				@request.body = @request_body

				@request.headers.merge!(
					'Content-Type'   => 'multipart/form-data; boundary="greatgoatsofgerta"',
					'Content-Length' => 11111,
					'User-Agent'     => 'Hotdogs',
					'Server'         => 'thingfish.laika.com',
					'Port'           => '3474'
				  )
				
				@config.spooldir_path = Pathname.new(Dir.tmpdir)
				@config.bufsize = 3
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
					'foo'      => 1,
					:title     => "a bogus filename",
					:useragent => 'Clumpy the Clown',
				  }

				ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
				parser.should_receive( :parse ).once.
					with( @request_body, 'greatgoatsofgerta' ).
					and_return([ entity_bodies, form_metadata ])

				thumb_metadata = {
					:relation => 'thumbnail',
					:format   => 'image/jpeg',
					:title    => 'filename1_thumb.jpg',
				  }

				yielded_pairs = {}
				@request.each_body do |res, parsed_metadata|
					if res == io1
						@request.append_related_resource( res, resource1, thumb_metadata )
					end
				end
				@request.each_body( true ) do |res, parsed_metadata|
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


			it "can return a flattened hash of entity bodies and merged metadata" do
				io1 = mock( "filehandle 1" )
				io2 = mock( "filehandle 2" )

				parser = mock( "multipart parser", :null_object => true )
				entity_bodies = {
					io1 => {:title  => "filename1",:format => "format1",:extent => 100292},
					io2 => {:title  => "filename2",:format => "format2",:extent => 100234}
				  }
				form_metadata = {
					'foo'      => 1,
					:title     => "a bogus filename",
					:useragent => 'Clumpy the Clown',
				  }

				ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
				parser.should_receive( :parse ).once.
					with( @request_body, 'greatgoatsofgerta' ).
					and_return([ entity_bodies, form_metadata ])

				@request.metadata[ io1 ][ 'appended' ] = 'something'
				bodies = @request.bodies

				bodies.keys.should have(2).members
				bodies.keys.should include( io1, io2 )

				bodies[ io1 ][ :title ].should == 'filename1'
				bodies[ io1 ][ :format ].should == 'format1'
				bodies[ io1 ][ :useragent ].should == "Hotdogs"
				bodies[ io1 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )
				bodies[ io1 ][ 'foo' ].should == 1
				bodies[ io1 ][ 'appended' ].should == 'something'

				bodies[ io2 ][ :title ].should == 'filename2'
				bodies[ io2 ][ :format ].should == "format2"
				bodies[ io2 ][ :useragent ].should == "Hotdogs"
				bodies[ io2 ][ :uploadaddress ].should == IPAddr.new( '127.0.0.1' )
				bodies[ io2 ][ 'foo' ].should == 1
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
					'foo'      => 1,
					:title     => "a bogus filename",
					:useragent => 'Clumpy the Clown',
				  }

				ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
				parser.should_receive( :parse ).once.
					with( @request_body, 'greatgoatsofgerta' ).
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
					'foo'      => 1,
					:title     => "a bogus filename",
					:useragent => 'Clumpy the Clown',
				  }

				ThingFish::MultipartMimeParser.stub!( :new ).and_return( parser )
				parser.should_receive( :parse ).once.
					with( @request_body, 'greatgoatsofgerta' ).
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


			### Body IO checks

			it "can sanity-check multiple IO objects that contain entity body data for EOF state" do
				io1 = mock( "filehandle 1" )
				sub_io1 = mock( "extracted filehandle 1" )
				io2 = mock( "filehandle 2" )

				parser = mock( "multipart parser", :null_object => true )
				entity_bodies = {
					io1 => {:title  => "filename1", :extent => 100292},
					io2 => {:title  => "filename2", :extent => 100234}
				  }
				related_resources = {
					io1 => { sub_io1 => {} }
				  }

				@request.instance_variable_set( :@entity_bodies, { io1 => {}, io2 => {} } )
				@request.instance_variable_set( :@form_metadata, {} )
				@request.instance_variable_set( :@related_resources, related_resources )

				io1.should_receive( :closed? ).and_return( false )
				io1.should_receive( :rewind )

				sub_io1.should_receive( :closed? ).and_return( false )
				sub_io1.should_receive( :rewind )

				io2.should_receive( :closed? ).and_return( false )
				io2.should_receive( :rewind )

				@request.check_body_ios
			end


			it "can replace an appended File IO object if it becomes closed" do
				io1 = mock( "filehandle 1" )
				sub_io1 = mock( "extracted filehandle 1" )
				clone_sub_io1 = mock( "extracted filehandle 1" )
				io2 = mock( "filehandle 2" )

				parser = mock( "multipart parser", :null_object => true )
				entity_bodies = {
					io1 => {:title  => "filename1", :extent => 100292},
					io2 => {:title  => "filename2", :extent => 100234}
				  }
				related_resources = {
					io1 => { sub_io1 => {} }
				  }

				@request.instance_variable_set( :@entity_bodies, { io1 => {}, io2 => {} } )
				@request.instance_variable_set( :@form_metadata, {} )
				@request.instance_variable_set( :@related_resources, related_resources )

				io1.should_receive( :closed? ).and_return( false )
				io1.should_receive( :rewind )

				sub_io1.should_receive( :closed? ).and_return( true )
				sub_io1.should_receive( :is_a? ).with( StringIO ).and_return( false )
				sub_io1.should_receive( :path ).and_return( :filepath )
				File.should_receive( :open ).with( :filepath, 'r' ).and_return( clone_sub_io1 )

				io2.should_receive( :closed? ).and_return( false )
				io2.should_receive( :rewind )

				@request.check_body_ios

				@request.related_resources[ io1 ].keys.should == [clone_sub_io1]
				@request.metadata.should_not have_key( sub_io1 )
				@request.metadata.should have_key( clone_sub_io1 )
			end


			it "can replace a StringIO object that contains entity body data if it becomes closed" do
				io1 = mock( "filehandle 1" )
				sub_io1 = mock( "extracted filehandle 1" )
				clone_sub_io1 = mock( "extracted filehandle 1" )
				io2 = mock( "filehandle 2" )

				parser = mock( "multipart parser", :null_object => true )
				entity_bodies = {
					io1 => {:title  => "filename1", :extent => 100292},
					io2 => {:title  => "filename2", :extent => 100234}
				  }
				related_resources = {
					io1 => { sub_io1 => {} }
				  }

				@request.instance_variable_set( :@entity_bodies, { io1 => {}, io2 => {} } )
				@request.instance_variable_set( :@form_metadata, {} )
				@request.instance_variable_set( :@related_resources, related_resources )

				io1.should_receive( :closed? ).and_return( false )
				io1.should_receive( :rewind )

				sub_io1.should_receive( :closed? ).and_return( true )
				sub_io1.should_receive( :is_a? ).with( StringIO ).and_return( true )
				sub_io1.should_receive( :string ).and_return( :datastring )
				StringIO.should_receive( :new ).with( :datastring ).and_return( clone_sub_io1 )

				io2.should_receive( :closed? ).and_return( false )
				io2.should_receive( :rewind )

				@request.check_body_ios

				@request.related_resources[ io1 ].keys.should == [clone_sub_io1]
				@request.metadata.should_not have_key( sub_io1 )
				@request.metadata.should have_key( clone_sub_io1 )
			end

		end

	end # "instance of POST request"

	describe " sent via XMLHTTPRequest" do
		before( :each ) do
			@config = ThingFish::Config.new
			@request = ThingFish::Request.parse( TESTING_GET_REQUEST, @config, @socket )
			@request.headers[ :x_requested_with ] = 'XmlHttpRequest'
		end

		it "knows that it's an ajax request" do
			@request.should be_an_ajax_request()
		end
	end # " sent via XMLHTTPRequest"


	describe " sent via pipelined HTTP request" do
		before( :each ) do
			@config = ThingFish::Config.new
			@request = ThingFish::Request.parse( TESTING_GET_REQUEST, @config, @socket )
			@request.headers[ :connection ] = 'keep-alive'
		end

		it "knows that it's a pipelined request" do
			@request.should be_keepalive()
		end
		
		it "refuses to pipeline to http 1.0 clients" do
			@request.should_receive( :http_version ).and_return( 1.0 )
			@request.should_not be_keepalive()
		end
		
	end # " sent via Pipelining"

end

# vim: set nosta noet ts=4 sw=4:
