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
		@request_headers   = mock( "request headers", :null_object => true )
		@request.stub!( :headers ).and_return( @request_headers )
		@response  = mock( "response", :null_object => true )
		@response_headers   = mock( "response headers", :null_object => true )
		@response.stub!( :headers ).and_return( @response_headers )
		@listener  = mock( "listener", :null_object => true )
		@metastore = mock( "metastore", :null_object => true )
		
		@mockmetadata = mock( "metadata proxy", :null_object => true )
		@metastore.stub!( :[] ).and_return( @mockmetadata )
		
		@listener.stub!( :metastore ).and_return( @metastore )
		@metastore.stub!( :is_a? ).and_return( true )
		@handler.listener = @listener
	end


	### Shared behaviors
	it_should_behave_like "A Handler"
	

	### Examples

	# 
	# GET
	# 
	it "returns a data-structure describing all metadata keys for GET /{handler}" do
		@request.should_receive( :path_info ).and_return( '/' )
		@metastore.should_receive( :get_all_property_keys ).
			and_return( TESTING_KEYS )

		@response_headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( STRINGIFIED_TESTING_KEYS )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a data-structure describing all values for a GET /{handler}/{key}" do
		@request.should_receive( :path_info ).and_return( '/invaders' )
		@metastore.should_receive( :get_all_property_values ).
			with( 'invaders' ).
			and_return( TESTING_VALUES )

		@response_headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TESTING_VALUES )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "returns a data-structure describing all metadata for a given uuid for GET /{handler}/{uuid}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@metastore.should_receive( :get_properties ).
			with( TEST_UUID ).
			and_return( TEST_RUBY_OBJECT )

		@response_headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TEST_RUBY_OBJECT )
		
		@handler.handle_get_request( @request, @response )
	end	

	#
	# PUT
	#
	it "updates a given uuid's metadata for a PUT to /{handler}/{uuid}/{key}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )
		
		@metastore.should_receive( :[] ).with( TEST_UUID ).and_return( @mockmetadata )
		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( true )
		@mockmetadata.should_receive( :[]= ).with( TEST_PROP, TEST_PROPVALUE )
		
		@response_headers.should_receive( :[]= ).with( :content_type, 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_put_request( @request, @response )
	end
	
	
	it "creates uuid's metadata property for a PUT to /{handler}/{uuid}/{key} if it " +
		"didn't previously exist." do
			
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :[] ).with( TEST_UUID ).and_return( @mockmetadata )
		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( false )
		@mockmetadata.should_receive( :[]= ).with( TEST_PROP, TEST_PROPVALUE )

		@response_headers.should_receive( :[]= ).with( :content_type, 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::CREATED )

		@handler.handle_put_request( @request, @response )		
	end
	
	it "responds with a 404 NOT FOUND response for a PUT to " +
	   "/{handler}/{non-existant uuid}"  do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )

		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( false )
		@response.should_not_receive( :body= )

		@handler.handle_put_request( @request, @response )		
	end
	
	it "updates a given uuid's metadata for a PUT to /{handler}/{uuid}"  do
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}

		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :body ).and_return( props )

		@metastore.should_receive( :has_uuid? ).
			with( TEST_UUID ).
			and_return( true )
		@metastore.should_receive( :[] ).with( TEST_UUID ).and_return( @mockmetadata )
		@mockmetadata.should_receive( :update ).with( props )

		@response_headers.should_receive( :[]= ).with( :content_type, 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_put_request( @request, @response )		
 	end
	
	it "doesn't allow a resource's 'extent' attribute to be updated via PUT"

	it "replies with a NOT_ACCEPTABLE response for PUT requests whose body isn't " +
	   "transformed into a Ruby Hash by the filters"

	#
	# POST
	#
	
	it "replaces a given UUID's metadata for a POST to /{handler}/{uuid}"	
	# it "replaces a given UUID's metadata for a POST to /{handler}/{uuid}" do
	# 	props = {
	# 		TEST_PROP  => TEST_PROPVALUE,
	# 		TEST_PROP2 => TEST_PROPVALUE2
	# 	}
	# 	@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
	# 	
	# 	@request.should_receive( :headers )
	# 	@request.should_receive( :body ).and_return( props )
	# 	@metastore.should_receive( :set_properties ).
	# 		with( TEST_UUID, props )
	# 		
	# 	@response_headers.should_receive( :[]= ).with( :content_type, 'text/plain' )
	# 	@response.should_receive( :body= ).with( /success/i )
	# 	
	# 	@handler.handle_put_request( @request, @response )
	# end
	
	it "doesn't allow a resource's 'extent' attribute to be replaced"

	

	# 
	# HTML filter interface
	# 
	
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

