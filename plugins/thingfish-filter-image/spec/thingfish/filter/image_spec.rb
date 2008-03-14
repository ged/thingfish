#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/image'
	require 'spec/lib/filter_behavior'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::ImageFilter do
	
	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		# Stub out some formats
		Magick.stub!( :formats ).and_return({ 'PNG' => '*rw-', 'GIF' => '*rw+', 'JPG' => '*rw-' })
		
		@filter = ThingFish::Filter.create( 'image', {} )

		@io = stub( "image upload IO object", :read => :imagedata )

		@request = mock( "request object" )
		@response = mock( "response object" )
		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )
		
		@request_metadata = { :format => 'image/png' }
		@request.stub!( :each_body ).and_yield( @io, @request_metadata )
	end

	after( :all ) do
		ThingFish.reset_logger
	end



	it_should_behave_like "A Filter"


	# Request (extraction) filtering

	it "doesn't attempt extraction on a GET" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@request.should_not_receive( :each_body )

		@filter.handle_request( @request, @response )
	end
	
	it "doesn't attempt extraction on a DELETE" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'DELETE' )
		@request.should_not_receive( :each_body )

		@filter.handle_request( @request, @response )
	end
	
	
	it "ignores entity bodies of media types it doesn't know how to open" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'PUT' )
		@request_metadata[ :format ] = 'dessert/tiramisu'
		Magick::Image.should_not_receive( :from_blob )
		@request.should_not_receive( :metadata )
		
		@filter.handle_request( @request, @response )
	end
	
	
	it "extracts dimension metadata from uploaded image data using RMagick" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'POST' )
		
		image = mock( "image object", :null_object => true )
		Magick::Image.should_receive( :from_blob ).with( :imagedata ).and_return([ image ])

		image.should_receive( :columns ).and_return( 100 )
		image.should_receive( :rows ).and_return( 200 )
		
		extracted_metadata = {}
		@request.should_receive( :metadata ).and_return({ @io => extracted_metadata })

		# Run the request filter
		@filter.handle_request( @request, @response )
		
		extracted_metadata['image_width'].should == 100
		extracted_metadata['image_height'].should == 200
	end
	
	
	it "extracts density metadata from uploaded image data using RMagick" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'POST' )
		
		image = mock( "image object", :null_object => true )
		Magick::Image.should_receive( :from_blob ).with( :imagedata ).and_return([ image ])

		image.should_receive( :density ).and_return( "72" )
		
		extracted_metadata = {}
		@request.should_receive( :metadata ).and_return({ @io => extracted_metadata })

		# Run the request filter
		@filter.handle_request( @request, @response )
		
		extracted_metadata['image_density'].should == "72"
	end
	
	
	it "extracts color depth metadata from uploaded image data" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'POST' )
		
		image = mock( "image object", :null_object => true )
		Magick::Image.should_receive( :from_blob ).with( :imagedata ).and_return([ image ])

		image.should_receive( :depth ).and_return( 16 )
		
		extracted_metadata = {}
		@request.should_receive( :metadata ).and_return({ @io => extracted_metadata })

		# Run the request filter
		@filter.handle_request( @request, @response )
		
		extracted_metadata['image_depth'].should == 16
	end
	
	
	it "extracts gamma level metadata from uploaded image data" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'POST' )
		
		image = mock( "image object", :null_object => true )
		Magick::Image.should_receive( :from_blob ).with( :imagedata ).and_return([ image ])

		image.should_receive( :gamma ).and_return( 0.2 )
		
		extracted_metadata = {}
		@request.should_receive( :metadata ).and_return({ @io => extracted_metadata })

		# Run the request filter
		@filter.handle_request( @request, @response )
		
		extracted_metadata['image_gamma'].should == 0.2
	end
	
	
	# Response (conversion) filtering

	it "doesn't try to convert non-GET responses" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'POST' )
		@response.should_not_receive( :body )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "doesn't try to convert responses that are already handled" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@request.should_receive( :accepts? ).and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'text/xml' )

		@response.should_not_receive( :body )
		
		@filter.handle_response( @response, @request )
	end


	it "doesn't try to convert downloads"

	
	it "doesn't try to convert formats it doesn't know about" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@request.should_receive( :accepts? ).and_return( false )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'text/xml' )

		@response.should_not_receive( :body )
		
		@filter.handle_response( @response, @request )
	end
	
	
	it "doesn't try to convert if the request doesn't have any explicitly accepted image types" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'image/jpeg' )

		acceptparam = mock( "accepted type" )
		@request.should_receive( :accepts? ).and_return( false )
		@request.should_receive( :accepted_types ).and_return([ acceptparam ])
		acceptparam.should_receive( :type ).and_return( 'text' )

		@response.should_not_receive( :body )

		@filter.handle_response( @response, @request )
	end

	it "doesn't try to convert if the request doesn't explicitly accept any formats it knows about" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'image/jpeg' )

		acceptparam = mock( "accepted type" )
		@request.should_receive( :accepts? ).and_return( false )
		@request.should_receive( :accepted_types ).and_return([ acceptparam ])
		acceptparam.should_receive( :type ).and_return( 'image' )
		acceptparam.should_receive( :subtype ).and_return( 'tiff' )
		acceptparam.should_receive( :mediatype ).at_least( :once ).and_return( 'image/tiff' )

		@response.should_not_receive( :body )

		@filter.handle_response( @response, @request )
	end


	it "converts image entity bodies from the source format to a format the client prefers" do
		@request.should_receive( :http_method ).at_least( :once ).and_return( 'GET' )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( 'image/jpeg' )

		acceptparam = mock( "accepted type" )
		@request.should_receive( :accepts? ).and_return( false )
		@request.should_receive( :accepted_types ).and_return([ acceptparam ])
		acceptparam.should_receive( :type ).and_return( 'image' )
		acceptparam.should_receive( :subtype ).and_return( 'png' )
		acceptparam.should_receive( :mediatype ).at_least( :once ).and_return( 'image/png' )

		image = mock( "image object", :null_object => true )
		image_filehandle = stub( "image filehandle", :read => :image_data )
		image_config = mock( "image config" )
		
		@response.should_receive( :body ).and_return( image_filehandle )
		Magick::Image.should_receive( :from_blob ).with( :image_data ).and_return( image )

		new_image_data = mock( "new image data", :null_object => true )

		image.should_receive( :to_blob ).
			and_yield( image_config ).
			and_return( new_image_data )
		new_image_data.should_receive( :length ).and_return( 4096 )
		image_config.should_receive( :format= ).with( 'PNG' )
		
		@response.should_receive( :body= ).with( new_image_data )
		@response_headers.should_receive( :[]= ).with( :content_length, 4096 )
		@response.should_receive( :content_type= ).with( 'image/png' )
		
		@filter.handle_response( @response, @request )
	end
	
end

# vim: set nosta noet ts=4 sw=4:

