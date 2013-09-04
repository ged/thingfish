#!/usr/bin/env ruby

require_relative 'helpers'

require 'rspec'
require 'thingfish'


describe Thingfish do

	before( :all ) do
		setup_logging()
		Thingfish.configure
	end

	before( :each ) do
		@png_io = StringIO.new( TEST_PNG_DATA.dup )
		@text_io = StringIO.new( TEST_TEXT_DATA.dup )
	end

	let( :handler ) { described_class.new(TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC) }


	#
	# Shared behaviors
	#

	it_should_behave_like "an object with Configurability"


	#
	# Examples
	#

	it "returns a version string if asked" do
		Thingfish.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		Thingfish.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
	end


	context "misc api" do

		let( :factory ) do
			Mongrel2::RequestFactory.new(
				:route => '/',
				:headers => {:accept => '*/*'})
		end

		it 'returns interesting configuration info' do
			req = factory.get( '/serverinfo',  content_type: 'text/plain' )
			res = handler.handle( req )

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
			res = handler.handle( req )

			expect( res.status_line ).to match( /201 created/i )
			expect( res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )
		end


		it 'replaces content via PUT' do
			uuid = handler.datastore.save( @text_io )
			handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.put( "/#{uuid}", @png_io, content_type: 'image/png' )
			res = handler.handle( req )

			expect( res.status ).to eq( HTTP::NO_CONTENT )
			expect( handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
			expect( handler.metastore.fetch(uuid) ).to include( 'format' => 'image/png' )
		end


		it "doesn't case about the case of the UUID when replacing content via PUT" do
			uuid = handler.datastore.save( @text_io )
			handler.metastore.save( uuid, {'format' => 'text/plain'} )

			req = factory.put( "/#{uuid.upcase}", @png_io, content_type: 'image/png' )
			res = handler.handle( req )

			expect( res.status ).to eq( HTTP::NO_CONTENT )
			expect( handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
			expect( handler.metastore.fetch(uuid) ).to include( 'format' => 'image/png' )
		end


		it 'can fetch all uploaded data' do
			text_uuid = handler.datastore.save( @text_io )
			handler.metastore.save( text_uuid, {
				'format' => 'text/plain',
				'extent' => @text_io.string.bytesize
			})
			png_uuid = handler.datastore.save( @png_io )
			handler.metastore.save( png_uuid, {
				'format' => 'image/png',
				'extent' => @png_io.string.bytesize
			})

			req = factory.get( '/' )
			res = handler.handle( req )
			content = Yajl::Parser.parse( res.body.read )

			expect( res.status_line ).to match( /200 ok/i )
			expect( res.headers.content_type ).to eq( 'application/json' )
			expect( content ).to be_a( Array )
			expect( content[0] ).to be_a( Hash )
			expect( content[0]['url'] ).to eq( "#{req.base_uri}/#{text_uuid}" )
			expect( content[0]['format'] ).to eq( "text/plain" )
			expect( content[0]['extent'] ).to eq( @text_io.string.bytesize )
			expect( content[1] ).to be_a( Hash )
			expect( content[1]['url'] ).to eq( "#{req.base_uri}/#{png_uuid}" )
			expect( content[1]['format'] ).to eq( 'image/png' )
			expect( content[1]['extent'] ).to eq( @png_io.string.bytesize )
		end


		it "can fetch an uploaded chunk of data" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {'format' => 'image/png'} )

			req = factory.get( "/#{uuid}" )
			result = handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( result.body.read ).to eq( @png_io.string )
			expect( result.headers.content_type ).to eq( 'image/png' )
		end


		it "doesn't care about the case of the UUID when fetching uploaded data" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {'format' => 'image/png'} )

			req = factory.get( "/#{uuid.upcase}" )
			result = handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( result.body.read ).to eq( @png_io.string )
			expect( result.headers.content_type ).to eq( 'image/png' )
		end


		it "can remove everything associated with an object id" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.delete( "/#{uuid}" )
			result = handler.handle( req )

			expect( result.status_line ).to match( /200 ok/i )
			expect( handler.metastore ).to_not include( uuid )
			expect( handler.datastore ).to_not include( uuid )
		end


		it "returns a 404 Not Found when asked to remove an object that doesn't exist" do
			req = factory.delete( "/#{TEST_UUID}" )
			result = handler.handle( req )

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
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.get( "/#{uuid}/metadata" )
			result = handler.handle( req )
			content = result.body.read

			content_hash = Yajl::Parser.parse( content )

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )
			expect( content_hash ).to be_a( Hash )
			expect( content_hash['extent'] ).to eq( 288 )
		end


		it "returns a 404 Not Found when fetching metadata for an object that doesn't exist" do
			req = factory.get( "/#{TEST_UUID}/metadata" )
			result = handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "can fetch a value for a specific metadata key" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.get( "/#{uuid}/metadata/extent" )
			result = handler.handle( req )
			content = Yajl::Parser.parse( result.body.read )

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )
			expect( content ).to be( 288 )
		end


		it "returns a 404 Not Found when fetching a specific metadata value for a uuid that doesn't exist" do
			req = factory.get( "/#{TEST_UUID}/metadata/extent" )
			result = handler.handle( req )

			expect( result.status_line ).to match( /404 not found/i )
		end


		it "doesn't error when fetching a nonexistent metadata value" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			req = factory.get( "/#{uuid}/metadata/hururrgghh" )
			result = handler.handle( req )

			content = Yajl::Parser.parse( result.body.read )

			expect( result.status ).to eq( 200 )
			expect( result.headers.content_type ).to eq( 'application/json' )

			expect( content ).to be_nil
		end


		it "can merge in new metadata for an existing resource" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			body_json = Yajl.dump({ 'comment' => 'Ignore me!' })
			req = factory.post( "/#{uuid}/metadata", body_json, 'Content-type' => 'application/json' )
			result = handler.handle( req )

			expect( result.status ).to eq( HTTP::NO_CONTENT )
			expect( handler.metastore.fetch(uuid, 'comment') ).to eq( 'Ignore me!' )
		end


		it "doesn't clobber protected metadata when merging metadata" do
			uuid = handler.datastore.save( @png_io )
			handler.metastore.save( uuid, {
				'format' => 'image/png',
				'extent' => 288,
			})

			body_json = Yajl.dump({ 'format' => 'text/plain', 'comment' => 'Ignore me!' })
			req = factory.post( "/#{uuid}/metadata", body_json, 'Content-type' => 'application/json' )
			result = handler.handle( req )

			expect( result.status ).to eq( HTTP::FORBIDDEN )
			expect( result.body.string ).to match( /unable to alter protected metadata/i )
			expect( result.body.string ).to match( /format/i )
			expect( handler.metastore.fetch(uuid, 'comment') ).to be_nil
			expect( handler.metastore.fetch(uuid, 'format') ).to eq( 'image/png' )
		end

	end
end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
