#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	pluginlibdir = plugindir + 'lib'

	basedir = plugindir.parent.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( pluginlibdir ) unless $LOAD_PATH.include?( pluginlibdir )
	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'
require 'spec/lib/handler_behavior'

require 'pathname'
require 'stringio'

require 'thingfish/constants'
require 'thingfish/handler/mailinglists'
require 'thingfish/exceptions'


include ThingFish::Constants,
		ThingFish::TestConstants,
		ThingFish::SpecHelpers

RFC822_DELIVERED_TO_LINES = [
	'mailing list beesammiches@example.com',
	'moderator for moderated-list@example.com',
	'mailing list burritoman@example.com',
	'moderator for burritoman@example.com',
	'owner for owned-list@example.com'
]

LIST_NAMES = RFC822_DELIVERED_TO_LINES.
	select {|delivered_to| delivered_to =~ /^mailing list/ }.
	map    {|delivered_to| delivered_to[ /(\S+)$/, 1]      }

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::MailinglistsHandler do

	before( :all ) do
		setup_logging( :fatal )
	end

	before(:each) do
		# resdir = @basedir + 'resources'
	    @handler  = ThingFish::Handler.create( 'mailinglists', '/ml' )
		@request  = mock( "request" ).as_null_object
		@response = mock( "response" ).as_null_object

		@request_headers  = mock( "request headers" ).as_null_object
		@request.stub!( :headers ).and_return( @request_headers )
		@response_headers  = mock( "response headers" ).as_null_object
		@response.stub!( :headers ).and_return( @response_headers )
		@response_data  = mock( "response data" ).as_null_object
		@response.stub!( :data ).and_return( @response_data )

		@metastore = mock( "metastore" )
		@metastore.stub!( :is_a? ).and_return( true )

		@daemon = mock( "daemon object" ).as_null_object
		@daemon.stub!( :metastore ).and_return( @metastore )

		@handler.on_startup( @daemon )
	end

	after( :all ) do
		reset_logging()
	end


	### Shared behaviors
	it_should_behave_like "a handler"


	### Examples
	it "responds with an Array of mailing list names if there's nothing in the path_info" do
		@metastore.
			should_receive( :get_all_property_values ).
			with( 'list_name' ).
			and_return( :list_names )

		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( :list_names )

		@handler.handle_get_request( '', @request, @response )
	end

	it "responds with an Integer count when requesting /listname/count" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		# there are some messages
		@metastore.should_receive( :find_exact_uuids ).and_return( [ 1, 2, 3, 4, 5 ] )
		@response.should_receive( :body= ).with( 5 )

		@handler.handle_get_request( 'bee-sammiches@guns.com/count', @request, @response )
	end

	it "responds with a 404 when requesting /listname for a non-existant list" do
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )

		@metastore.should_receive( :find_exact_uuids ).and_return( [] )
		@handler.handle_get_request( 'bee.sammiches@guns.museum', @request, @response )
	end

	it "responds with a Hash of count and list_post_date when requesting /listname" do
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		@metastore.should_receive( :find_exact_uuids ).twice.and_return( %w[1 2 3] )
		@metastore.should_receive( :get_property ).with( '1', :rfc822_date ).
			and_return( 'Sun, 3 Feb 2008 21:40:46 -0800' )
		@metastore.should_receive( :get_property ).with( '2', :rfc822_date ).
			and_return( 'Sun, 3 Feb 2008 23:28:42 -0800' )
		@metastore.should_receive( :get_property ).with( '3', :rfc822_date ).
			and_return( 'Sun, 3 Jun 2007 00:05:08 -0700' )

		@response.should_receive( :body= ).with(
			{
				'count' => 3,
				'last_post_date' => Date.parse( 'Sun, 3 Feb 2008 23:28:42 -0800' )
			}
		)

		@handler.handle_get_request( 'bee+sammiches@big-guns.nu', @request, @response )
	end

	it "responds with a 404 for when requesting /listname/count for a non-existant list" do
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )

		@metastore.should_receive( :find_exact_uuids ).and_return( [] )
		@handler.handle_get_request( 'flash-photography@guns.deadhooker.drunk.com.au/count', 
			@request, @response )
	end

	it "responds with a Date when requesting /listname/last_post_date" do
		@metastore.should_receive( :find_exact_uuids ).
			with( 'list_name', 'beesammiches@guns.com' ).
			and_return( %w[1 2 3 4 5] )
		@metastore.should_receive( :get_property ).with( '1', :rfc822_date ).
			and_return( 'Sun, 3 Feb 2008 21:40:46 -0800' )
		@metastore.should_receive( :get_property ).with( '2', :rfc822_date ).
			and_return( 'Sun, 3 Feb 2008 23:28:42 -0800' )
		@metastore.should_receive( :get_property ).with( '3', :rfc822_date ).
			and_return( 'Sun, 3 Jun 2007 00:05:08 -0700' )
		@metastore.should_receive( :get_property ).with( '4', :rfc822_date ).
			and_return( 'Sun, 3 Jun 2007 00:14:34 -0700' )
		@metastore.should_receive( :get_property ).with( '5', :rfc822_date ).
			and_return( 'Sun, 3 Jun 2007 00:28:07 -0700' )

		@response.should_receive( :body= ).with( Date.parse('Sun, 3 Feb 2008 23:28:42 -0800') )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )

		@handler.handle_get_request( 'beesammiches@guns.com/last_post_date', @request, @response )
	end

	it "responds with a 404 for when requesting /listname/last_post_date for a non-existant list" do
		@response.should_receive( :status= ).with( HTTP::NOT_FOUND )

		@metastore.should_receive( :find_exact_uuids ).and_return( [] )
		@handler.handle_get_request( 'beesammiches@guns.com/last_post_date', @request, @response )
	end
end

# vim: set nosta noet ts=4 sw=4:
