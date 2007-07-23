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
	require 'thingfish/handler'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


describe "A Handler", :shared => true do
	include ThingFish::TestConstants
	include ThingFish::TestHelpers

	it "handles uncaught exceptions with a SERVER_ERROR response if the response " +
		"header hasn't been sent" do

		request   = mock( "request", :null_object => true )
		response  = mock( "response", :null_object => true )
		headers   = mock( "headers", :null_object => true )
		out       = mock( "out", :null_object => true )
		
		request.should_receive( :params ).and_raise( "testing" )
		response.should_receive( :header_sent ).at_least(:once).and_return( false )
		response.should_receive( :reset )
		response.should_receive( :start ).
			with( HTTP::SERVER_ERROR, true ).
			and_yield( headers, out )
		out.should_receive( :write ).once.with( "testing" )

		lambda {
			@handler.process( request, response )
		}.should_not raise_error()
	end
	

	it "handles requests for unimplemented methods with a METHOD_NOT_ALLOWED response" do
		params = {
			'REQUEST_METHOD' => 'GLORP',
		}
		
		request   = mock( "request", :null_object => true )
		response  = mock( "response", :null_object => true )
		headers   = mock( "headers", :null_object => true )
		out       = mock( "out", :null_object => true )
		
		request.should_receive( :params ).at_least(:once).and_return( params )
		response.should_receive( :start ).
			with( HTTP::METHOD_NOT_ALLOWED, true ).
			and_yield( headers, out )
		headers.should_receive( :[]= ).with( 'Allow', /([A-Z]+(,\s)?)+/ )
		out.should_receive( :write ).once.with( /GLORP/ )

		lambda {
			@handler.process( request, response )
		}.should_not raise_error()
	end
	
end

