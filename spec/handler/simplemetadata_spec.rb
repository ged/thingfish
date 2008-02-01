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

		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( STRINGIFIED_TESTING_KEYS )
		
		@handler.handle_get_request( @request, @response )
	end


	it "returns a data-structure describing all values for a GET /{handler}/{key}" do
		@request.should_receive( :path_info ).and_return( '/invaders' )
		@metastore.should_receive( :get_all_property_values ).
			with( 'invaders' ).
			and_return( TESTING_VALUES )

		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TESTING_VALUES )
		
		@handler.handle_get_request( @request, @response )
	end
	
	
	it "returns a data-structure describing all metadata for a given uuid for GET /{handler}/{uuid}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@metastore.should_receive( :get_properties ).
			with( TEST_UUID ).
			and_return( TEST_RUBY_OBJECT )

		@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
		@response.should_receive( :body= ).with( TEST_RUBY_OBJECT )
		
		@handler.handle_get_request( @request, @response )
	end	


	it "responds with a a default (404) response for a GET to an unknown {uuid}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@metastore.should_receive( :has_uuid? ).
			with( TEST_UUID ).
			and_return( false )
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@handler.handle_get_request( @request, @response )		
	end
	

	it "responds with a a default (404) response for a GET to an unknown URI" do
		@request.should_receive( :path_info ).
			at_least( :once ).
			and_return( '/wicka-wicka-pow-pow' )
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@handler.handle_get_request( @request, @response )		
	end
	
	
	#
	# PUT
	#
	
	### PUT /
	
	it "responds with a 200 SUCCESS response for a PUT to /{handler}" do
		body = {
			TEST_UUID => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			},
			TEST_UUID2 => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			}
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( 'PUT' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )

		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( true )

		@metastore.should_receive( :update_safe_properties ).
			with( TEST_UUID, body[TEST_UUID] )
		@metastore.should_receive( :update_safe_properties ).
			with( TEST_UUID2, body[TEST_UUID2] )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_put_request( @request, @response )		
	end
	
	
	it "responds with a 409 CONFLICT response for a PUT to /{handler} if the " +
	   "entity body contains a UUID that doesn't exist in the metastore"  do
		body = {
			TEST_UUID => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			},
			TEST_UUID2 => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			}
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( false )

		@response.should_receive( :body= ).with an_instance_of( Array )
		@response.should_receive( :status= ).with( HTTP::CONFLICT )
		
		@handler.handle_put_request( @request, @response )		
	end


	it "replies with an UNSUPPORTED_MEDIA_TYPE response for PUT requests to / " +
	   "whose body isn't transformed into a Ruby Hash by the filters" do
		@request.should_receive( :path_info ).and_return( '/' )
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'application/something-bizarre' )
		
		@request.should_not_receive( :body )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).
			with( %r{application/something-bizarre}i )
		@response.should_receive( :status= ).with( HTTP::UNSUPPORTED_MEDIA_TYPE )

		@handler.handle_put_request( @request, @response )		
	end


	
	### PUT /uuid
	
	it "responds with a 404 NOT FOUND response for a PUT to " +
	   "/{handler}/{non-existant uuid}"  do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( false )
		@response.should_not_receive( :body= )

		@handler.handle_put_request( @request, @response )		
	end

	
	it "safely updates a given uuid's metadata for a PUT to /{handler}/{uuid}"  do
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}

		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :http_method ).and_return( 'PUT' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		@request.should_receive( :body ).and_return( props )

		@metastore.should_receive( :has_uuid? ).
			with( TEST_UUID ).
			and_return( true )
		@metastore.should_receive( :update_safe_properties ).with( TEST_UUID, props )	

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_put_request( @request, @response )		
 	end


	### PUT /uuid/key
	
	it "updates a given uuid's metadata for a PUT to /{handler}/{uuid}/{key}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( true )		
		@metastore.should_receive( :set_safe_property ).
			with( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_put_request( @request, @response )
	end
	
	
	it "creates uuid's metadata property for a PUT to /{handler}/{uuid}/{key} if it " +
		"didn't previously exist." do
			
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( false )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::CREATED )

		@handler.handle_put_request( @request, @response )		
	end


	it "replies with a FORBIDDEN for a PUT to /{handler}/{uuid}/{key} if it " +
		"is a system reserved property" do
			
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' +  'extent' )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, 'extent' ).
			and_return( true )

		@metastore.should_receive( :set_safe_property ).
			with( TEST_UUID, 'extent', TEST_PROPVALUE ).
			and_raise( ThingFish::MetaStoreError.new( 'used by the system' ) )
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /metastoreerror/i )
		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )

		@handler.handle_put_request( @request, @response )		
	end


	it "responds with a a default (404) response for a PUT to an unknown URI" do
		@request.should_receive( :path_info ).
			at_least( :once ).
			and_return( '/wicka-wicka-pow-pow' )
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@handler.handle_put_request( @request, @response )		
	end


	
	#
	# POST
	#
	
	### POST /
	
	it "responds with a 200 SUCCESS response for a POST to /{handler}" do
		body = {
			TEST_UUID => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			},
			TEST_UUID2 => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			}
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( 'POST' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( true )

		@metastore.should_receive( :set_safe_properties ).
			with( TEST_UUID, body[TEST_UUID] )
		@metastore.should_receive( :set_safe_properties ).
			with( TEST_UUID2, body[TEST_UUID2] )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_post_request( @request, @response )		
	end
	
	
	it "responds with a 409 CONFLICT response for a POST to /{handler} if the " +
	   "entity body contains a UUID that doesn't exist in the metastore"  do
		body = {
			TEST_UUID => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			},
			TEST_UUID2 => {
				TEST_PROP => TEST_PROPVALUE,
				TEST_PROP2 => TEST_PROPVALUE2,
			}
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( false )

		@response.should_receive( :body= ).with an_instance_of( Array )
		@response.should_receive( :status= ).with( HTTP::CONFLICT )
		
		@handler.handle_post_request( @request, @response )		
	end


	it "replies with an UNSUPPORTED_MEDIA_TYPE response for POST requests to / " +
	   "whose body isn't transformed into a Ruby Hash by the filters" do
		@request.should_receive( :path_info ).and_return( '/' )
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'application/something-bizarre' )
		@request.should_not_receive( :body )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).
			with( %r{application/something-bizarre}i )
		@response.should_receive( :status= ).with( HTTP::UNSUPPORTED_MEDIA_TYPE )

		@handler.handle_post_request( @request, @response )		
	end


	
	### POST /uuid
	
	it "responds with a 404 NOT FOUND response for a POST to " +
	   "/{handler}/{non-existant uuid}"  do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )

		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( false )
		@response.should_not_receive( :body= )

		@handler.handle_post_request( @request, @response )		
	end


	it "replies with an UNSUPPORTED_MEDIA_TYPE response for POST requests to /{uuid} " +
	   "whose body isn't transformed into a Ruby Hash by the filters" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'application/something-bizarre' )
		@request.should_not_receive( :body )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).
			with( %r{application/something-bizarre}i )
		@response.should_receive( :status= ).with( HTTP::UNSUPPORTED_MEDIA_TYPE )

		@handler.handle_post_request( @request, @response )		
	end

	
	it "safely updates a given uuid's metadata for a POST to /{handler}/{uuid}"  do
		props = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2
		}

		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :http_method ).and_return( 'POST' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		@request.should_receive( :body ).and_return( props )

		@metastore.should_receive( :has_uuid? ).
			with( TEST_UUID ).
			and_return( true )
		@metastore.should_receive( :set_safe_properties ).with( TEST_UUID, props )	

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_post_request( @request, @response )		
 	end


	### POST /uuid/key
	
	it "updates a given uuid's metadata for a POST to /{handler}/{uuid}/{key}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( true )		
		@metastore.should_receive( :set_safe_property ).
			with( TEST_UUID, TEST_PROP, TEST_PROPVALUE )
		
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_post_request( @request, @response )
	end
	
	
	it "creates uuid's metadata property for a POST to /{handler}/{uuid}/{key} if it " +
		"didn't previously exist." do
			
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, TEST_PROP ).
			and_return( false )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::CREATED )

		@handler.handle_post_request( @request, @response )		
	end


	it "replies with a FORBIDDEN for a POST to /{handler}/{uuid}/{key} if it " +
		"is a system reserved property" do
			
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' +  'extent' )
		@request.should_receive( :body ).and_return( TEST_PROPVALUE )

		@metastore.should_receive( :has_property? ).
			with( TEST_UUID, 'extent' ).
			and_return( true )

		@metastore.should_receive( :set_safe_property ).
			with( TEST_UUID, 'extent', TEST_PROPVALUE ).
			and_raise( ThingFish::MetaStoreError.new( 'used by the system' ) )
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /metastoreerror/i )
		@response.should_receive( :status= ).with( HTTP::FORBIDDEN )

		@handler.handle_post_request( @request, @response )		
	end
	
	
	it "responds with a a default (404) response for a POST to an unknown URI" do
		@request.should_receive( :path_info ).
			at_least( :once ).
			and_return( '/wicka-wicka-pow-pow' )
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@handler.handle_post_request( @request, @response )		
	end



	#
	# DELETE
	#
	
	### DELETE /
	
	it "responds with a 200 SUCCESS response for a DELETE to /{handler}" do
		body = {
			TEST_UUID  => [ TEST_PROP, TEST_PROP2 ],
			TEST_UUID2 => [ TEST_PROP, TEST_PROP2 ]
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( 'DELETE' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )

		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( true )

		@metastore.should_receive( :delete_safe_properties ).
			with( TEST_UUID, body[TEST_UUID] )
		@metastore.should_receive( :delete_safe_properties ).
			with( TEST_UUID2, body[TEST_UUID2] )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_delete_request( @request, @response )		
	end

	
	it "replies with an UNSUPPORTED_MEDIA_TYPE response for DELETE requests to / " +
	   "whose body isn't transformed into a Ruby Hash by the filters" do
		@request.should_receive( :path_info ).and_return( '/' )
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'application/something-bizarre' )
		@request.should_not_receive( :body )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).
			with( %r{application/something-bizarre}i )
		@response.should_receive( :status= ).with( HTTP::UNSUPPORTED_MEDIA_TYPE )

		@handler.handle_delete_request( @request, @response )		
	end


	it "responds with a 409 CONFLICT response for a DELETE to /{handler} if the " +
	   "entity body contains a UUID that doesn't exist in the metastore"  do
		body = {
			TEST_UUID  => [ TEST_PROP, TEST_PROP2 ],
			TEST_UUID2 => [ TEST_PROP, TEST_PROP2 ]
		}

		@request.should_receive( :path_info ).and_return( '/'  )
		@request.should_receive( :body ).and_return( body )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( true )
		@metastore.should_receive( :has_uuid? ).with( TEST_UUID2 ).and_return( false )

		@response.should_receive( :body= ).with an_instance_of( Array )
		@response.should_receive( :status= ).with( HTTP::CONFLICT )
		
		@handler.handle_delete_request( @request, @response )		
	end

	
	### DELETE /uuid
	
	it "responds with a 404 NOT FOUND response for a DELETE to " +
	   "/{handler}/{non-existant uuid}"  do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )

		@metastore.should_receive( :has_uuid? ).with( TEST_UUID ).and_return( false )
		@response.should_not_receive( :body= )

		@handler.handle_delete_request( @request, @response )		
	end

	
	it "safely removes a given uuid's metadata for a DELETE to /{handler}/{uuid}"  do
		props = [ TEST_PROP, TEST_PROP2 ]

		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :http_method ).and_return( 'DELETE' )
		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		@request.should_receive( :body ).and_return( props )

		@metastore.should_receive( :has_uuid? ).
			with( TEST_UUID ).
			and_return( true )
		@metastore.should_receive( :delete_safe_properties ).with( TEST_UUID, props )	

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )

		@handler.handle_delete_request( @request, @response )		
 	end


	it "replies with an UNSUPPORTED_MEDIA_TYPE response for DELETE requests to /{uuid} " +
	   "whose body isn't transformed into a Ruby Hash by the filters" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID )
		@request.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'application/something-bizarre' )
		@request.should_not_receive( :body )

		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).
			with( %r{application/something-bizarre}i )
		@response.should_receive( :status= ).with( HTTP::UNSUPPORTED_MEDIA_TYPE )

		@handler.handle_delete_request( @request, @response )		
	end


	### DELETE /uuid/key
	
	it "removes a given uuid's metadata for a DELETE to /{handler}/{uuid}/{key}" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID + '/' + TEST_PROP  )
		@metastore.should_receive( :delete_safe_property ).
			with( TEST_UUID, TEST_PROP )
		
		@response.should_receive( :content_type= ).with( 'text/plain' )
		@response.should_receive( :body= ).with( /success/i )
		@response.should_receive( :status= ).with( HTTP::OK )
		
		@handler.handle_delete_request( @request, @response )
	end
	
	
	it "responds with a a default (404) response for a DELETE to an unknown URI" do
		@request.should_receive( :path_info ).
			at_least( :once ).
			and_return( '/wicka-wicka-pow-pow' )
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@handler.handle_delete_request( @request, @response )		
	end



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
	
	
	#
	# Misc
	#
	
	it "raises a error on update_metastore() with an unhandled http method" do
		@request.should_receive( :path_info ).and_return( '/' + TEST_UUID  )
		@request.should_receive( :body ).and_return( {} )

		@request.should_receive( :content_type ).and_return( RUBY_MIMETYPE )
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( 'TRACE' )

		@response.should_not_receive( :status= ).with( HTTP::OK )

		lambda {
			@handler.handle_put_request( @request, @response )
		}.should raise_error( RuntimeError, /unknown method/i )
	end
end

