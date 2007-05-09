#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'pathname'
require 'spec/runner'
require 'stringio'
require 'thingfish/constants'

require 'thingfish/handler/status'



#####################################################################
###	C O N T E X T S
#####################################################################

include ThingFish::Constants

describe "A status handler with no stats filters" do
	before(:all) do
		ThingFish.reset_logger
	end

	before(:each) do
		@request  = mock( "request", :null_object => true )
		@response = mock( "response", :null_object => true )
		@headers  = mock( "headers", :null_object => true )
		@out      = mock( "out", :null_object => true )
		@listener = mock( "listener", :null_object => true )

		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
	    @handler  = ThingFish::Handler.create( 'status', 'resource_dir' => resdir )
	end


	### Specs

	it "doesn't register any filters with its listener" do
		classifier = Mongrel::URIClassifier.new
		classifier.register( '/status', @handler )

		@listener.should_receive( :classifier ).at_least(1).and_return( classifier )
		@listener.should_receive( :register ).once

		@handler.listener = @listener
	end


	it "doesn't return a body for a HEAD request" do
		params = {
			'REQUEST_METHOD' => 'HEAD',
			'PATH_INFO' => '',
		}
		@request.should_receive( :params ).at_least(1).and_return( params )
		@response.should_receive( :start ).and_yield( @headers, @out )

		@headers.should_receive( :[]= ).with( 'Content-Type', 'text/html' )
		@out.should_not_receive( :write )

		@handler.process( @request, @response )
	end


	it "returns a status page for a GET request" do
		params = {
			'REQUEST_METHOD' => 'GET',
			'PATH_INFO' => '',
		}
		@request.should_receive( :params ).at_least(1).and_return( params )
		@response.should_receive( :start ).and_yield( @headers, @out )

		@headers.should_receive( :[]= ).with( 'Content-Type', 'text/html' )
	    @out.should_receive( :write ).with( /ThingFish Status/ )
	
		classifier = Mongrel::URIClassifier.new
		classifier.register( '/status', @handler )
		@listener.should_receive( :classifier ).at_least(1).and_return( classifier )
		@handler.listener = @listener
	
		@handler.process( @request, @response )
	end

	it "returns a METHOD_NOT_ALLOWED for anything but a GET or a HEAD" do
		params = {
			'REQUEST_METHOD' => 'POST',
			'PATH_INFO' => '',
		}
		@request.should_receive( :params ).at_least(1).and_return( params )
		@response.should_receive( :start ).with( HTTP::METHOD_NOT_ALLOWED, true ).
			and_yield( @headers, @out )

		@headers.should_receive( :[]= ).with( 'Allow', 'GET, HEAD' )
	    @out.should_receive( :write ).with( /not allowed/i )
		
		@handler.process( @request, @response )
	end

end


describe "A status handler with stats filters" do
	before(:each) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
		options = {
			'resource_dir' => resdir,
			'stat_uris' => %w[/ /metadata /admin],
		}
		
		@listener = mock( "listener", :null_object => true )
	    @handler  = ThingFish::Handler.create( 'status', options )
	end

	it "registers a StatisticsFilter with its listener for each configured URI" do
		@listener.
			should_receive( :register ).
			with( :string, duck_type(:process, :dump), true ).
			exactly(3).times
		
		@handler.listener = @listener
	end
	
end

# vim: set nosta noet ts=4 sw=4:
