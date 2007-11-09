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
	require 'spec/lib/handler_behavior'
	require 'time'

	require 'thingfish'
	require 'thingfish/handler/simplemetadata'
	require 'thingfish/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::SimpleMetadataHandler do
	before(:each) do
		# ThingFish.logger.level = Logger::DEBUG
		ThingFish.logger.level = Logger::FATAL
		
		options = {
			:uris => ['/metadata']
		}

		@handler   = ThingFish::SimpleMetadataHandler.new( options )
		@request   = mock( "request", :null_object => true )
		@response  = mock( "response", :null_object => true )
		@headers   = mock( "headers", :null_object => true )
		@response.stub!( :headers ).and_return( @headers )
		@listener  = mock( "listener", :null_object => true )
		@metastore = mock( "metastore", :null_object => true )
		
		@listener.stub!( :metastore ).and_return( @metastore )
	end
	
	it "raises an exception when the system is using a non-simple metastore" do
		@metastore.
			should_receive( :is_a? ).
			with( ThingFish::SimpleMetaStore ).
			and_return( false )

		lambda {
			@handler.listener = @listener
		}.should raise_error( ThingFish::ConfigError, /simplemetastore/i )
	end	
end

describe ThingFish::SimpleMetadataHandler, " set up with a simple metastore" do
	TESTING_KEYS = [ :some, :keys, :for, :testing ]
	STRINGIFIED_TESTING_KEYS = TESTING_KEYS.collect {|k| k.to_s }
	TESTING_VALUES = %w{ zim ger dib }
	
	before(:each) do
		# ThingFish.logger.level = Logger::DEBUG
		ThingFish.logger.level = Logger::FATAL
		
		options = {
			:uris => ['/metadata']
		}

		@handler   = ThingFish::SimpleMetadataHandler.new( options )
		@request   = mock( "request", :null_object => true )
		@response  = mock( "response", :null_object => true )
		@headers   = mock( "headers", :null_object => true )
		@response.stub!( :headers ).and_return( @headers )
		@listener  = mock( "listener", :null_object => true )
		@metastore = mock( "metastore", :null_object => true )
		
		@listener.stub!( :metastore ).and_return( @metastore )
		@metastore.stub!( :is_a? ).and_return( true )
		@handler.listener = @listener
	end


	# Shared behaviors
	it_should_behave_like "A Handler"
	
	# Examples

	it "returns a page describing all metadata keys for a text/html GET to /metadata" do
		template = stub( "ERB template", :result => :rendered_output )

		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@request.should_receive( :path_info ).
			and_return( '/' )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( true )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@response.should_receive( :body= ).with( :rendered_output )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a data-structure describing all metadata keys for a non-html GET to /metadata" do
		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@request.should_receive( :path_info ).
			and_return( '/' )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@handler.should_not_receive( :get_erb_resource )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( STRINGIFIED_TESTING_KEYS )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a page describing all values for a metadata key (text/html GET)" do
		template = stub( "ERB template", :result => :rendered_output )

		@request.should_receive( :path_info ).
			and_return( '/invaders' )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( true )

		@metastore.should_receive( :get_all_property_values ).
			with( 'invaders' ).
			and_return( TESTING_VALUES )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@response.should_receive( :body= ).with( :rendered_output )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a page describing all values for a metadata key (non-html GET)" do
		@request.should_receive( :path_info ).
			and_return( '/invaders' )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@metastore.should_receive( :get_all_property_values ).
			with( 'invaders' ).
			and_return( TESTING_VALUES )

		@handler.should_not_receive( :get_erb_resource )
		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TESTING_VALUES )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "returns a page describing all metadata for a given uuid (text/html GET)" do
		template = stub( "ERB template", :result => :rendered_output )

		@request.should_receive( :path_info ).
			and_return( '/' + TEST_UUID )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( true )

		@metastore.should_receive( :get_properties ).
			with( TEST_UUID ).
			and_return( TEST_RUBY_OBJECT )

		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@response.should_receive( :body= ).with( :rendered_output )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a page describing all metadata for a given uuid (non-html GET)" do
		@request.should_receive( :path_info ).
			and_return( '/' + TEST_UUID )
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@metastore.should_receive( :get_properties ).
			with( TEST_UUID ).
			and_return( TEST_RUBY_OBJECT )

		@handler.should_not_receive( :get_erb_resource )
		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TEST_RUBY_OBJECT )
		
		@handler.handle_get_request( @request, @response )
	end	
end

