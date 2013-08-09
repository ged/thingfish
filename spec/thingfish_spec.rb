#!/usr/bin/env ruby

require_relative 'helpers'

require 'rspec'
require 'thingfish'


describe ThingFish do

	before( :all ) do
		setup_logging()
		ThingFish.configure
	end


	let( :handler ) { described_class.new(TEST_APPID, TEST_SEND_SPEC, TEST_RECV_SPEC) }
	let( :factory ) { Mongrel2::RequestFactory.new(:route => '/') }
	let( :text_data ) { "Some stuff." }
	let( :png_data ) do
		("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMA" +
		"AQAABQABDQottAAAAABJRU5ErkJggg==").unpack('m').first
	end


	#
	# Shared behaviors
	#

	it_should_behave_like "an object with Configurability"


	#
	# Examples
	#

	it "returns a version string if asked" do
		ThingFish.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		ThingFish.version_string(true).should =~ /\w+ [\d.]+ \(build [[:xdigit:]]+\)/
	end


	it 'accepts a POSTed upload' do
		req = factory.post( '/', text_data, content_type: 'text/plain' )
		res = handler.handle( req )
		expect( res.status_line ).to match( /201 created/i )
		expect( res.headers.location.to_s ).to match( %r:/#{UUID_PATTERN}$: )
	end


	it "can fetch an uploaded chunk of data" do
		upload = factory.post( '/', png_data, content_type: 'image/png' )
		upload_res = handler.handle( upload )

		url = URI( upload_res.headers.location )
		fetch = factory.get( url.path )
		result = handler.handle( fetch )

		expect( result.status_line ).to match( /200 ok/i )
		expect( result.body.read ).to eq( png_data )
		expect( result.headers.content_type ).to eq( 'image/png' )
	end


end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
