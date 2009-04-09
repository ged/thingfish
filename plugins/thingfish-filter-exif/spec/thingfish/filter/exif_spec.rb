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

require 'pathname'
require 'tmpdir'
require 'spec/runner'
require 'spec/lib/constants'
require 'spec/lib/helpers'
require 'spec/lib/filter_behavior'
require 'thingfish/constants'
require 'thingfish/acceptparam'

require 'thingfish/filter/exif'


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::ExifFilter do
	include ThingFish::Constants
	include ThingFish::TestConstants

	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
	    @filter = ThingFish::Filter.create( 'exif' )

		@io = StringIO.new( TEST_CONTENT )
		@io.stub!( :path ).and_return( :a_dummy_path )
		@response = stub( "response object" )

		@request = mock( "request object" , :null_object => true )
		@request.stub!( :http_method ).and_return( :POST )

		@exif_parser = mock( "exif parser", :null_object => true )
		EXIFR::JPEG.stub!( :new ).and_return( @exif_parser )
		EXIFR::TIFF.stub!( :new ).and_return( @exif_parser )
	end

	after( :all ) do
		reset_logging()
	end


	### Shared behaviors
	it_should_behave_like "A Filter"


	### Filter-specific tests

	it "extracts exif metadata from uploaded jpeg images" do
		exif_data = {
			:model => 'Pinhole Camera 2000'
		}

		extracted_metadata = {
			:'exif:width'	=> 320,
			:'exif:height'	=> 240,
			:'exif:bits'	=> 8,
			:'exif:comment'	=> 'Trundled by Grundle',
			:'exif:model' 	=> 'Pinhole Camera 2000',
		}

		request_metadata = { :format => 'image/jpeg' }
		@request.stub!( :each_body ).and_yield( @io, request_metadata )

		@exif_parser.should_receive( :exif? ).and_return( true )
		@exif_parser.should_receive( :exif ).and_return( exif_data )

		@exif_parser.should_receive( :width ).and_return( 320 )
		@exif_parser.should_receive( :height ).and_return( 240 )
		@exif_parser.should_receive( :bits ).and_return( 8 )
		@exif_parser.should_receive( :comment ).and_return( 'Trundled by Grundle' )
		@exif_parser.should_receive( :model ).and_return( 'Pinhole Camera 2000' )

		@request.should_receive( :append_metadata_for ).with( @io, extracted_metadata )

		@filter.handle_request( @request, @response )
	end


	it "extracts exif metadata from uploaded tiff images" do
		exif_data = {
			:model => 'Pinhole Camera 2000'
		}

		extracted_metadata = {
			:'exif:width'	=> 320,
			:'exif:height'	=> 240,
			:'exif:size'	=> '320x240',
			:'exif:model'	=> 'Pinhole Camera 2000',
		}

		request_metadata = { :format => 'image/tiff' }
		@request.stub!( :each_body ).and_yield( @io, request_metadata )

		@exif_parser.should_not_receive( :exif? )
		@exif_parser.should_receive( :to_hash ).and_return( exif_data )

		@exif_parser.should_receive( :width ).and_return( 320 )
		@exif_parser.should_receive( :height ).and_return( 240 )
		@exif_parser.should_receive( :size ).and_return( '320x240' )
		@exif_parser.should_receive( :model ).and_return( 'Pinhole Camera 2000' )

		@request.should_receive( :append_metadata_for ).with( @io, extracted_metadata )

		@filter.handle_request( @request, @response )
	end


	it "ignores all non jpeg/tiff uploads" do
		request_metadata = { :format => 'lunchmeat/oliveloaf' }
		@request.stub!( :each_body ).and_yield( @io, request_metadata )

		@filter.should_not_receive( :extract_exif )
		@request.should_not_receive( :metadata )

		@filter.handle_request( @request, @response )
	end


	it "ignores non-POST requests" do
		@request.should_receive( :http_method ).any_number_of_times.
			and_return( :GET )
		@request.should_not_receive( :each_body )

		@filter.handle_request( @request, @response )
	end

end

# vim: set nosta noet ts=4 sw=4:
