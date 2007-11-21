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

	it "returns a data-structure describing all metadata keys for GET /{handler}" do
		@request.should_receive( :path_info ).and_return( '/' )
		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( STRINGIFIED_TESTING_KEYS )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a data-structure describing all values for a GET /{handler}/{key}" do
		@request.should_receive( :path_info ).and_return( '/invaders' )
		@metastore.should_receive( :get_all_property_values ).
			with( 'invaders' ).
			and_return( TESTING_VALUES )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TESTING_VALUES )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "returns a data-structure describing all metadata for a given uuid for GET /{handler}/{uuid}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@metastore.should_receive( :get_properties ).
			with( TEST_UUID ).
			and_return( TEST_RUBY_OBJECT )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TEST_RUBY_OBJECT )
		
		@handler.handle_get_request( @request, @response )
	end	


	# HTML filter interface
	
	it "renders HTML output for a GET /{handler}" do
		template = stub( "ERB template", :result => :rendered_output )
		body = stub( "Body data structure" )

		@request.should_receive( :path_info ).and_return( '/' )
		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@handler.make_html_content( body, @request, @response ).should == :rendered_output
	end

	
	it "renders HTML output for a GET /{handler}/{key}" do
		template = stub( "ERB template", :result => :rendered_output )
		body = stub( "Body data structure" )

		@request.should_receive( :path_info ).and_return( '/invaders' )
		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@handler.make_html_content( body, @request, @response ).should == :rendered_output
	end

	
	it "renders HTML output for a GET /{handler}/{uuid}" do
		template = stub( "ERB template", :result => :rendered_output )
		body = stub( "Body data structure" )

		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@handler.should_receive( :get_erb_resource ).and_return( template )
		template.should_receive( :result ).and_return( :rendered_output )
	
		@handler.make_html_content( body, @request, @response ).should == :rendered_output
	end


	it "raises an error when asked to render HTML for any other path_info" do
		template = stub( "ERB template", :result => :rendered_output )
		body = stub( "Body data structure" )

		@request.should_receive( :path_info ).
			at_least( :once ).
			and_return( '/zim/ger/tak' )
	
		lambda {
			@handler.make_html_content( body, @request, @response )
		}.should raise_error( RuntimeError, /unable to build html/i )
	end
	
end

