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

	let( :handler )      { described_class.new(TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC) }
	let( :factory )      { Mongrel2::RequestFactory.new(:route => '/') }


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


	it 'accepts a POSTed upload' do
		req = factory.post( '/', TEST_TEXT_DATA, content_type: 'text/plain' )
		res = handler.handle( req )

		expect( res.status_line ).to match( /201 created/i )
		expect( res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )
	end


	it 'replaces content via PUT' do
		uuid = handler.datastore.save( @text_io )
		handler.metastore.save( uuid, {format: 'text/plain'} )

		req = factory.put( "/#{uuid}", @png_io, content_type: 'image/png' )
		res = handler.handle( req )

		expect( res.status ).to eq( HTTP::NO_CONTENT )
		expect( handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
		expect( handler.metastore.fetch(uuid) ).to include( format: 'image/png' )
	end


	it "doesn't case about the case of the UUID when replacing content via PUT" do
		uuid = handler.datastore.save( @text_io )
		handler.metastore.save( uuid, {format: 'text/plain'} )

		req = factory.put( "/#{uuid.upcase}", @png_io, content_type: 'image/png' )
		res = handler.handle( req )

		expect( res.status ).to eq( HTTP::NO_CONTENT )
		expect( handler.datastore.fetch(uuid).read ).to eq( TEST_PNG_DATA )
		expect( handler.metastore.fetch(uuid) ).to include( format: 'image/png' )
	end


	it "can fetch an uploaded chunk of data" do
		uuid = handler.datastore.save( @png_io )
		handler.metastore.save( uuid, {format: 'image/png'} )

		req = factory.get( "/#{uuid}" )
		result = handler.handle( req )

		expect( result.status_line ).to match( /200 ok/i )
		expect( result.body.read ).to eq( @png_io.string )
		expect( result.headers.content_type ).to eq( 'image/png' )
	end


	it "doesn't care about the case of the UUID when fetching uploaded data" do
		uuid = handler.datastore.save( @png_io )
		handler.metastore.save( uuid, {format: 'image/png'} )

		req = factory.get( "/#{uuid.upcase}" )
		result = handler.handle( req )

		expect( result.status_line ).to match( /200 ok/i )
		expect( result.body.read ).to eq( @png_io.string )
		expect( result.headers.content_type ).to eq( 'image/png' )
	end


	it "can remove everything associated with an object id" do
		uuid = handler.datastore.save( @png_io )
		handler.metastore.save( uuid, {format: 'image/png'} )

		req = factory.delete( "/#{uuid}" )
		result = handler.handle( req )

		expect( uuid ).to_not be_nil
		expect( result.status_line ).to match( /200 ok/i )
		expect( handler.metastore ).to_not include( uuid )
		expect( handler.datastore ).to_not include( uuid )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
