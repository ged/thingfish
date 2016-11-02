#!/usr/bin/env ruby

require_relative '../helpers'

require 'rspec'
require 'thingfish/handler'
require 'thingfish/processor'


describe Thingfish::Handler do

	EVENT_SOCKET_URI = 'tcp://127.0.0.1:0'

	before( :all ) do
		Thingfish::Handler.configure( :event_socket_uri => EVENT_SOCKET_URI )
		Thingfish::Handler.install_plugins
	end

	before( :each ) do
		@png_io  = StringIO.new( TEST_PNG_DATA.dup )
		@text_io = StringIO.new( TEST_TEXT_DATA.dup )
		@handler = described_class.new( TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC )
	end


	after( :each ) do
		@handler.shutdown
	end

	# let( :handler ) { described_class.new(TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC) }


	#
	# Shared behaviors
	#

	it_should_behave_like "an object with Configurability"


	#
	# Examples
	#

	context "misc api" do

		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => '*/*'})
		end

		it 'returns interesting configuration info' do
			req = factory.get( '/serverinfo',  content_type: 'text/plain' )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /200 ok/i )
			expect( res.headers ).to include( 'x-thingfish' )
		end

	end


	context "datastore api" do

		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => '*/*'})
		end


		it 'accepts a POSTed upload' do
			req = factory.post( '/', TEST_TEXT_DATA, content_type: 'text/plain' )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /201 created/i )
			expect( res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )
		end


		it "accepts an upload POSTED via Mongrel's async API'" do
			# Need the config to look up the async upload path relative to the server's chroot
			Mongrel2::Config.db = Mongrel2::Config.in_memory_db
			Mongrel2::Config.init_database
			server( 'thingfish' ) do
				chroot    ''
				host 'localhost' do
					route '/', handler( 'tcp://127.0.0.1:9900', 'thingfish' )
				end
			end

			spool_path = '/var/spool/uploadfile.672'
			upload_size = 645_000
			fh = instance_double( "File", size: upload_size, rewind: 0, pos: 0, :pos= => nil,
				read: TEST_TEXT_DATA )
			expect( FileTest ).to receive( :exist? ).with( spool_path ).and_return( true )
			expect( File ).to receive( :open ).
				with( spool_path, 'r', encoding: Encoding::ASCII_8BIT ).
				and_return( fh )

			start_req = factory.post( '/', nil,
				x_mongrel2_upload_start: spool_path,
				content_length: upload_size,
				content_type: 'text/plain' )
			upload_req = factory.post( '/', nil,
				x_mongrel2_upload_start: spool_path,
				x_mongrel2_upload_done: spool_path,
				content_length: upload_size,
				content_type: 'text/plain' )

			start_res = @handler.dispatch_request( start_req )
			upload_res = @handler.dispatch_request( upload_req )

			expect( start_res ).to be_nil

			expect( upload_res.status_line ).to match( /201 created/i )
			expect( upload_res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )
		end


		it "accepts resources added to a POSTed resource by processors" do
			imageio = StringIO.new( TEST_PNG_DATA )

			subclass = Class.new( described_class )
			subclass.filter( :request ) do |req|
				req.add_related_resource( imageio,
					relationship: 'thumbnail',
					format: 'image/png',
					extent: TEST_PNG_DATA.bytesize )
			end
			subclass.metastore = 'memory'
			subclass.datastore = 'memory'
			handler = subclass.new( TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC )

			req = factory.post( '/', TEST_TEXT_DATA, content_type: 'text/plain' )
			res = handler.handle( req )

			metastore = handler.metastore
			oid = res.headers.x_thingfish_uuid
			related_oid = metastore.fetch_related_oids( oid ).first

			expect(
				metastore.fetch_value(related_oid, 'uploadaddress')
			).to eq( metastore.fetch_value(oid, 'uploadaddress') )
		end


		it "allows additional metadata to be attached to uploads via X-Thingfish-* headers" do
			headers = {
				content_type: 'text/plain',
				x_thingfish_title: 'Muffin the Panda Goes To School',
				x_thingfish_tags: 'rapper,ukraine,potap',
			}
			req = factory.post( '/', TEST_TEXT_DATA, headers )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /201 created/i )
			expect( res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )

			uuid = res.headers.x_thingfish_uuid
			expect( @handler.metastore.fetch_value(uuid, 'title') ).
				to eq( 'Muffin the Panda Goes To School' )
			expect( @handler.metastore.fetch_value(uuid, 'tags') ).to eq( 'rapper,ukraine,potap' )
		end


		it 'replaces content via PUT' do
			uuid = @handler.datastore.save( @text_io )
			@handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.put( "/#{uuid}", @png_io, content_type: 'image/png' )
			res = @handler.handle( req )

			expect( res.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
			expect( @handler.metastore.fetch(uuid) ).to include( 'format' => 'image/png' )
		end


		it "doesn't care about the case of the UUID when replacing content via PUT" do
			uuid = @handler.datastore.save( @text_io )
			@handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.put( "/#{uuid.upcase}", @png_io, content_type: 'image/png' )
			res = @handler.handle( req )

			expect( res.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
			expect( @handler.metastore.fetch(uuid) ).to include( 'format' => 'image/png' )
		end


		it 'can fetch all uploaded data' do
			text_uuid = @handler.datastore.save( @text_io )
			@handler.metastore.save( text_uuid, {
				'format' => 'text/plain',
				'extent' => @text_io.string.bytesize
			})
			png_uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( png_uuid, {
				'format' => 'image/png',
				'extent' => @png_io.string.bytesize
			})

			req = factory.get( '/' )
			res = @handler.handle( req )
			content = Yajl::Parser.parse( res.body.read )

			expect( res.status_line ).to match( /200 ok/i )
			expect( res.headers.content_type ).to eq( 'application/json' )
			expect( content ).to be_a( Array )
			expect( content[0] ).to be_a( Hash )
			expect( content[0]['uri'] ).to eq( "#{req.base_uri}#{text_uuid}" )
			expect( content[0]['format'] ).to eq( "text/plain" )
			expect( content[0]['extent'] ).to eq( @text_io.string.bytesize )
			expect( content[1] ).to be_a( Hash )
			expect( content[1]['uri'] ).to eq( "#{req.base_uri}#{png_uuid}" )
			expect( content[1]['format'] ).to eq( 'image/png' )
			expect( content[1]['extent'] ).to eq( @png_io.string.bytesize )
		end


		it 'can fetch all related data for a single resource' do
			main_uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( main_uuid, {
				'format' => 'image/png',
				'extent' => @png_io.string.bytesize
			})
			related_uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( related_uuid, {
				'format'       => 'image/png',
				'extent'       => @png_io.string.bytesize,
				'relation'     => main_uuid,
				'relationship' => "twinsies"
			})

			req = factory.get( "/#{main_uuid}/related" )
			res = @handler.handle( req )
			content = Yajl::Parser.parse( res.body.read )

			expect( res.status_line ).to match( /200 ok/i )
			expect( res.headers.content_type ).to eq( 'application/json' )
			expect( content ).to be_a( Array )
			expect( content[0] ).to be_a( Hash )
			expect( content[0]['uri'] ).to eq( "#{req.base_uri}#{related_uuid}" )
			expect( content[0]['format'] ).to eq( "image/png" )
			expect( content[0]['extent'] ).to eq( @png_io.string.bytesize )
			expect( content[0]['uuid'] ).to eq( related_uuid )
			expect( content[0]['relation'] ).to eq( main_uuid )
		end


		it 'can fetch a related resource by name' do
			main_uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( main_uuid, {
				'format' => 'image/png',
				'extent' => @png_io.string.bytesize
			})
			related_uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( related_uuid, {
				'format'       => 'image/png',
				'extent'       => @png_io.string.bytesize,
				'relation'     => main_uuid,
				'relationship' => "twinsies"
			})

			req = factory.get( "/#{main_uuid}/related/twinsies" )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /200 ok/i )
			expect( res.headers.content_type ).to eq( 'image/png' )
			expect( res.body.read ).to eq( TEST_PNG_DATA )
		end


		it "404s when attempting to fetch a resource related to a non-existant resource" do
			req = factory.get( "/#{TEST_UUID}/related/twinsies" )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /404 not found/i )
		end


		it "404s when attempting to fetch a related resource that doesn't exist" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => @png_io.string.bytesize
			})

			req = factory.get( "/#{uuid}/related/twinsies" )
			res = @handler.handle( req )

			expect( res.status_line ).to match( /404 not found/i )
		end


		it "can fetch an uploaded chunk of data" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {'format' => 'image/png'} )

			req = factory.get( "/#{uuid}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( result.body.read ).to eq( @png_io.string )
			expect( result.headers.content_type ).to eq( 'image/png' )
		end


		it "returns a 404 Not Found when asked to fetch an object that doesn't exist" do
			req = factory.get( "/#{TEST_UUID}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "returns a 404 Not Found when asked to fetch an object that doesn't exist in the metastore" do
			uuid = @handler.datastore.save( @png_io )

			req = factory.get( "/#{uuid}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "doesn't care about the case of the UUID when fetching uploaded data" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {'format' => 'image/png'} )

			req = factory.get( "/#{uuid.upcase}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( result.body.read ).to eq( @png_io.string )
			expect( result.headers.content_type ).to eq( 'image/png' )
		end


		it "adds browser cache headers to resources with a checksum attribute" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, 'format' => 'image/png', 'checksum' => '123456' )

			req = factory.get( "/#{uuid}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( result.headers.etag ).to eq( '123456' )
		end


		it "returns a 304 not modified for unchanged client cache requests" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, 'format' => 'image/png', 'checksum' => '123456' )

			req = factory.get( "/#{uuid}" )
			req.headers[ :if_none_match ] = '123456'
			result = @handler.handle( req )

			expect( result.status_line ).to match( /304 not modified/i )
			expect( result.body.read ).to be_empty
		end



		it "can remove everything associated with an object id" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.delete( "/#{uuid}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( @handler.metastore.include?(uuid) ).to be_falsey
			expect( @handler.datastore.include?(uuid) ).to be_falsey
		end


		it "returns a 404 Not Found when asked to remove an object that doesn't exist" do
			req = factory.delete( "/#{TEST_UUID}" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


	end


	context "metastore api" do

		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => 'application/json'})
		end

		it "can fetch the metadata associated with uploaded data" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png',
				'extent'  => 288,
				'created' => Time.at(1378313840),
			})

			req = factory.get( "/#{uuid}/metadata" )
			result = @handler.handle( req )
			content = result.body.read

			content_hash = Yajl::Parser.parse( content )

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )
			expect( content_hash ).to be_a( Hash )
			expect( content_hash['extent'] ).to eq( 288 )
			expect( content_hash['created'] ).to eq( Time.at(1378313840).to_s )
		end


		it "returns a 404 Not Found when fetching metadata for an object that doesn't exist" do
			req = factory.get( "/#{TEST_UUID}/metadata" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "can fetch a value for a single metadata key" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req     = factory.get( "/#{uuid}/metadata/extent" )
			result  = @handler.handle( req )
			result.body.rewind
			content = result.body.read

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )
			expect( content ).to eq( "288" )
		end


		it "returns a 404 Not Found when fetching a single metadata value for a uuid that doesn't exist" do
			req = factory.get( "/#{TEST_UUID}/metadata/extent" )
			result = @handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "doesn't error when fetching a non-existent metadata value" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.get( "/#{uuid}/metadata/hururrgghh" )
			result = @handler.handle( req )

			content = Yajl::Parser.parse( result.body.read )

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )

			expect( content ).to be_nil
		end


		it "can merge in new metadata for an existing resource with a POST" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			body_json = Yajl.dump({ 'comment' => 'Ignore me!' })
			req = factory.post( "/#{uuid}/metadata", body_json, 'Content-type' => 'application/json' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'Ignore me!' )
		end


		it "returns FORBIDDEN when attempting to merge metadata with operational keys" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			body_json = Yajl.dump({ 'format' => 'text/plain', 'comment' => 'Ignore me!' })
			req = factory.post( "/#{uuid}/metadata", body_json, 'Content-type' => 'application/json' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::FORBIDDEN )
			expect( result.body.string ).to match( /unable to alter protected metadata/i )
			expect( result.body.string ).to match( /format/i )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to be_nil
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
		end


		it "can create single metadata values with a POST" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.post( "/#{uuid}/metadata/comment", "urrrg", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::CREATED )
			expect( result.headers.location ).to match( %r|#{uuid}/metadata/comment$| )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'urrrg' )
		end


		it "returns NOT_FOUND when attempting to create metadata for a non-existent object" do
			req = factory.post( "/#{TEST_UUID}/metadata/comment", "urrrg", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NOT_FOUND )
			expect( result.body.string ).to match( /no such object/i )
		end


		it "returns CONFLICT when attempting to create a single metadata value if it already exists" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png',
				'extent'  => 288,
				'comment' => 'nill bill'
			})

			req = factory.post( "/#{uuid}/metadata/comment", "urrrg", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::CONFLICT )
			expect( result.body.string ).to match( /already exists/i )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'nill bill' )
		end


		it "can create single metadata values with a PUT" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.put( "/#{uuid}/metadata/comment", "urrrg", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'urrrg' )
		end


		it "can replace a single metadata value with a PUT" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png',
				'extent'  => 288,
				'comment' => 'nill bill'
			})

			req = factory.put( "/#{uuid}/metadata/comment", "urrrg", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'urrrg' )
		end


		it "returns FORBIDDEN when attempting to replace a operational metadata value with a PUT" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png',
				'extent'  => 288,
				'comment' => 'nill bill'
			})

			req = factory.put( "/#{uuid}/metadata/format", "image/gif", 'Content-type' => 'text/plain' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::FORBIDDEN )
			expect( result.body.string ).to match( /protected metadata/i )
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
		end


		it "can replace all metadata with a PUT" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'    => 'image/png',
				'extent'    => 288,
				'comment'   => 'nill bill',
				'ephemeral' => 'butterflies',
			})

			req = factory.put( "/#{uuid}/metadata", %[{"comment":"Yeah."}],
			                   'Content-type' => 'application/json' )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to eq( 'Yeah.' )
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
			expect( @handler.metastore ).to_not include( 'ephemeral' )
		end


		it "can remove all non-default metadata with a DELETE" do
			timestamp = Time.now.getgm
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'        => 'image/png',
				'extent'        => 288,
				'comment'       => 'nill bill',
				'useragent'     => 'Inky/2.0',
				'uploadaddress' => '127.0.0.1',
				'created'       => timestamp,
			})

			req = factory.delete( "/#{uuid}/metadata" )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( result.body.string ).to be_empty
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
			expect( @handler.metastore.fetch_value(uuid, 'extent') ).to eq( 288 )
			expect( @handler.metastore.fetch_value(uuid, 'uploadaddress') ).to eq( '127.0.0.1' )
			expect( @handler.metastore.fetch_value(uuid, 'created') ).to eq( timestamp )

			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to be_nil
			expect( @handler.metastore.fetch_value(uuid, 'useragent') ).to be_nil
		end


		it "can remove a single metadata value with DELETE" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png',
				'comment' => 'nill bill'
			})

			req = factory.delete( "/#{uuid}/metadata/comment" )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( result.body.string ).to be_empty
			expect( @handler.metastore.fetch_value(uuid, 'comment') ).to be_nil
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
		end


		it "returns FORBIDDEN when attempting to remove a operational metadata value with a DELETE" do
			uuid = @handler.datastore.save( @png_io )
			@handler.metastore.save( uuid, {
				'format'  => 'image/png'
			})

			req = factory.delete( "/#{uuid}/metadata/format" )
			result = @handler.handle( req )

			expect( result.status ).to eq( HTTP::FORBIDDEN )
			expect( result.body.string ).to match( /protected metadata/i )
			expect( @handler.metastore.fetch_value(uuid, 'format') ).to eq( 'image/png' )
		end
	end


	context "processors" do

		before( :all ) do
			@original_filters = described_class.filters.dup
			described_class.filters.replace({ :request => [], :response => [], :both => [] })
		end

		after( :all ) do
			described_class.filters.replace( @original_filters )
		end

		before( :each ) do
			described_class.processors.clear
			described_class.filters.values.each( &:clear )
		end


		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => '*/*'})
		end

		let!( :test_processor ) do
			klass = Class.new( Thingfish::Processor ) do
				extend Loggability
				log_to :thingfish

				handled_types 'text/plain'

				def initialize( * )
					super
					@was_called = false
				end
				attr_reader :was_called

				def self::name; 'Thingfish::Processor::Test'; end
				def on_request( request )
					@was_called = true
					self.log.debug "Adding a comment to a request."
					request.add_metadata( 'test:comment' => "Yo, it totally worked." )

					io = StringIO.new( "Chunkers!" )
					io.rewind
					related_metadata = { 'format' => 'text/plain', 'relationship' => 'comment' }
					request.add_related_resource( io, related_metadata )
				end
				def on_response( response )
					@was_called = true
					content = response.body.read
					response.body.rewind
					response.body.print( content.reverse )
					response.body.rewind
				end
			end
			# Re-call inherited so it associates the processor plugin with its name
			Thingfish::Processor.inherited( klass )
			klass
		end


		it "loads configured processors when it is instantiated" do
			logger = Loggability[ described_class ]
			logger.debug( "*** %p" % described_class.filters )
			logger.debug( "*** %p" % @original_filters )

			described_class.configure( :processors => %w[test] )

			expect( described_class.processors ).to be_an( Array )

			processor = described_class.processors.first
			expect( processor ).to be_an_instance_of( test_processor )
		end


		it "processes requests" do
			described_class.configure( :processors => %w[test] )

			req = factory.post( '/', TEST_TEXT_DATA, content_type: 'text/plain' )
			res = @handler.handle( req )
			uuid = res.headers.x_thingfish_uuid

			Thingfish.logger.debug "Metastore contains: %p" % [ @handler.metastore.storage ]

			expect( @handler.metastore.fetch(uuid) ).
				to include( 'test:comment' => 'Yo, it totally worked.')
			related_uuids = @handler.metastore.fetch_related_oids( uuid )
			expect( related_uuids.size ).to eq( 1 )

			r_uuid = related_uuids.first.downcase
			expect( @handler.metastore.fetch_value(r_uuid, 'relation') ).to eq( uuid )
			expect( @handler.metastore.fetch_value(r_uuid, 'format') ).to eq( 'text/plain' )
			expect( @handler.metastore.fetch_value(r_uuid, 'extent') ).to eq( 9 )
			expect( @handler.metastore.fetch_value(r_uuid, 'relationship') ).to eq( 'comment' )

			expect( @handler.datastore.fetch(r_uuid).read ).to eq( 'Chunkers!' )
		end


		it "doesn't process requests for paths under the metadata uri-space" do
			described_class.configure( :processors => %w[test] )
			processor = described_class.processors.first

			req = factory.post( "/#{TEST_UUID}/metadata", TEST_TEXT_DATA, content_type: 'text/plain' )
			@handler.handle( req )

			expect( processor.was_called ).to be_falsey
		end


		it "processes responses" do
			described_class.configure( :processors => %w[test] )

			uuid = @handler.datastore.save( @text_io )
			@handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.get( "/#{uuid}" )
			res = @handler.handle( req )

			res.body.rewind
			expect( res.body.read ).to eq( TEST_TEXT_DATA.reverse )
		end


		it "doesn't process responses for paths under the metadata uri-space" do
			described_class.configure( :processors => %w[test] )
			processor = described_class.processors.first

			uuid = @handler.datastore.save( @text_io )
			@handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.get( "/#{uuid}/metadata" )
			@handler.handle( req )

			expect( processor.was_called ).to be_falsey
		end
	end


	context "event hook" do

		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => '*/*'})
		end

		before( :each ) do
			@handler.setup_event_socket

			@subsock = Mongrel2.zmq_context.socket( :SUB )
			@subsock.linger = 0
			@subsock.subscribe( '' )
			@subsock.connect( @handler.event_socket.endpoint )
		end

		after( :each ) do
			@subsock.close
		end

		it "publishes notifications about uploaded assets to a PUBSUB socket" do
			req = factory.post( '/', TEST_TEXT_DATA, content_type: 'text/plain' )
			res = @handler.handle( req )

			handles = ZMQ.select( [@subsock], nil, nil, 0 )
			expect( handles ).to be_an( Array )
			expect( handles[0].size ).to eq( 1 )
			expect( handles[0].first ).to be( @subsock )

			event = @subsock.recv
			expect( @subsock.rcvmore? ).to be_truthy
			expect( event ).to eq( 'created' )

			resource = @subsock.recv
			expect( @subsock.rcvmore? ).to be_falsey
			expect( resource ).to match( /^\{"uuid":"#{UUID_PATTERN}"\}$/ )
		end
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
