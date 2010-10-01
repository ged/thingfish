#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

require 'pathname'
require 'tmpdir'
require 'spec'
require 'spec/lib/constants'
require 'spec/lib/filter_behavior'
require 'thingfish/constants'
require 'thingfish/acceptparam'

require 'thingfish/filter/mp3'


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::MP3Filter do
	include ThingFish::Constants
	include ThingFish::TestConstants

	TEST_MP3_TITLE = "Meatphone"
	TEST_ARTIST    = "The Artist Formerly Known as Pork"
	TEST_ALBUM     = "Lung Bacon"
	TEST_COMMENTS  = ["Frazzles", "3d glasses", "your face is stupid"]
	TEST_YEAR      = 2004
	TEST_GENRE     = 11
	TEST_TRACKNUM  = 4

	EXTRACTED_METADATA = {
		:'mp3:frequency' => 44000,
		:'mp3:bitrate'   => 128,
		:'mp3:vbr'       => true,
		:'mp3:tracknum'  => TEST_TRACKNUM,
		:'mp3:title'     => TEST_MP3_TITLE,
		:'mp3:artist'    => TEST_ARTIST,
		:'mp3:album'     => TEST_ALBUM,
		:'mp3:comments'  => TEST_COMMENTS,
		:'mp3:year'      => TEST_YEAR,
		:'mp3:genre'     => TEST_GENRE,
	}

	MP3_SPECDIR = Pathname.new( __FILE__ ).dirname.parent.parent
	MP3_DATADIR = MP3_SPECDIR + 'data'

	JPEG_MAGIC_REGEXP = /^\377\330\377\340\000\020JFIF/
	PNG_MAGIC_REGEXP = /^\x89PNG/


	before( :each ) do
		@filter = ThingFish::Filter.create( 'mp3' )

		@response = stub( "response object" )
		@request_metadata = { :format => 'audio/mpeg' }
		@request = mock( "request object" )
	end


	### Shared behaviors
	it_should_behave_like "A Filter"

	it "ignores non-POST requests" do
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( :GET )
		@request.should_not_receive( :each_body )

		@filter.handle_request( @request, @response )
	end


	### Filter-specific tests

	describe ' given an mp3 that has id3 data' do

		before( :each ) do
			@io = StringIO.new( TEST_CONTENT )
			@io.stub!( :path ).and_return( :a_dummy_path )

			@request.stub!( :http_method ).and_return( :POST )
			@request.stub!( :each_body ).and_yield( @io, @request_metadata )

			@mp3info = mock( "MP3 info object", :null_object => true )
			Mp3Info.stub!( :new ).and_return( @mp3info )
			@id3tag = mock( "ID3 tag object", :null_object => true )
			@mp3info.stub!( :tag ).and_return( @id3tag )
		end

		it "extracts MP3 metadata from ID3v1 tags of uploaded MP3s" do
			@mp3info.should_receive( :samplerate ).and_return( 44000 )
			@mp3info.should_receive( :bitrate ).and_return( 128 )
			@mp3info.should_receive( :vbr ).and_return( true )

			@id3tag.should_receive( :tracknum ).and_return( TEST_TRACKNUM )
			@id3tag.should_receive( :title ).and_return( TEST_MP3_TITLE )
			@id3tag.should_receive( :artist ).and_return( TEST_ARTIST )
			@id3tag.should_receive( :album ).and_return( TEST_ALBUM )
			@id3tag.should_receive( :comments ).and_return( TEST_COMMENTS )
			@id3tag.should_receive( :year ).and_return( TEST_YEAR )
			@id3tag.should_receive( :genre ).and_return( TEST_GENRE )

			@filter.should_receive( :extract_images ).and_return( {} )
			@request.should_receive( :append_metadata_for ).with( @io, EXTRACTED_METADATA )
			@filter.handle_request( @request, @response )
		end


		it "extracts MP3 metadata from ID3v2 (v2.2.0) tags of uploaded MP3s" do
			extracted_metadata = {}
			v2tag = mock( "ID3v2 tag", :null_object => true )

			@mp3info.should_receive( :samplerate ).and_return( 44000 )
			@mp3info.should_receive( :bitrate ).and_return( 128 )
			@mp3info.should_receive( :vbr ).and_return( true )

			@id3tag.should_receive( :title ).and_return( nil )
			@id3tag.should_receive( :artist ).and_return( nil )
			@id3tag.should_receive( :album ).and_return( nil )
			@id3tag.should_receive( :year ).and_return( nil )
			@id3tag.should_receive( :tracknum ).and_return( nil )
			@id3tag.should_receive( :comments ).and_return( nil )
			@id3tag.should_receive( :genre ).and_return( nil )

			@mp3info.should_receive( :hastag2? ).
				at_least( :once ).
				and_return( true )
			@mp3info.should_receive( :tag2 ).
				at_least( :once ).
				and_return( v2tag )

			v2tag.should_receive(:TT2).and_return( TEST_MP3_TITLE )
			v2tag.should_receive(:TP1).and_return( TEST_ARTIST )
			v2tag.should_receive(:TAL).and_return( TEST_ALBUM )
			v2tag.should_receive(:TYE).and_return( TEST_YEAR )
			v2tag.should_receive(:TRK).and_return( TEST_TRACKNUM )
			v2tag.should_receive(:COM).and_return( TEST_COMMENTS )
			v2tag.should_receive(:TCO).and_return( TEST_GENRE )

			@filter.should_receive( :extract_images ).and_return( {} )
			@request.should_receive( :append_metadata_for ).with( @io, EXTRACTED_METADATA )
			@filter.handle_request( @request, @response )
		end


		it "ignores all non-mp3 uploads" do
			@request_metadata[ :format ] = 'dessert/tapioca'
			Mp3Info.should_not_receive( :new )
			@request.should_not_receive( :metadata )

			@filter.handle_request( @request, @response )
		end


		it "normalizes id3 values" do
			@mp3info.should_receive( :samplerate ).and_return( 44000 )
			@mp3info.should_receive( :bitrate ).and_return( 128 )
			@mp3info.should_receive( :vbr ).and_return( true )

			@id3tag.should_receive( :tracknum ).and_return( TEST_TRACKNUM )
			@id3tag.should_receive( :year ).and_return( TEST_YEAR )
			@id3tag.should_receive( :genre ).and_return( TEST_GENRE )

			@id3tag.should_receive( :title ).and_return( TEST_MP3_TITLE + "\x0" )
			@id3tag.should_receive( :artist ).and_return( "\n" + TEST_ARTIST + "   \n\n" )
			@id3tag.should_receive( :album ).and_return( nil )
			@id3tag.should_receive( :comments ).and_return([
			   TEST_COMMENTS[0] + "\x0",
			   "  " + TEST_COMMENTS[1] + "\n\n",
			   TEST_COMMENTS[2]
			])

			# The nil should be transformed into an '(unknown)', but everything else should
			# be the same
			normalized_values = EXTRACTED_METADATA.dup
			normalized_values[:'mp3:album'] = "(unknown)"

			@filter.should_receive( :extract_images ).and_return( {} )
			@request.should_receive( :append_metadata_for ).with( @io, normalized_values )
			@filter.handle_request( @request, @response )
		end
	end


	### Album art parsing

	describe ' given an mp3 that has id3 data with art' do

		before( :each ) do
			@request_metadata = { :format => 'audio/mpeg' }
			@request.stub!( :http_method ).and_return( :POST )
		end


		it "extracts album art from an uploaded mp3 (single, PIC)" do
			testdata = MP3_DATADIR + 'PIC-1-image.mp3'
			io = testdata.open
			art_hash = {
				:format => 'image/jpeg',
				:extent => 7369,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}

			@request.stub!( :each_body ).and_yield( io, @request_metadata )
			@request.stub!( :append_metadata_for )
			StringIO.should_receive( :new ).with( JPEG_MAGIC_REGEXP ).and_return( :imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :imgdata_io, art_hash )

			@filter.handle_request( @request, @response )
		end


		it "extracts album art from an uploaded mp3 (multiple, PIC)" do
			testdata = MP3_DATADIR + 'PIC-2-images.mp3'
			io = testdata.open
			jpg_art_hash = {
				:format => 'image/jpeg',
				:extent => 7369,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}
			png_art_hash = {
				:format => 'image/png',
				:extent => 18031,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}

			@request.stub!( :each_body ).and_yield( io, @request_metadata )
			@request.stub!( :append_metadata_for )

			StringIO.should_receive( :new ).with( JPEG_MAGIC_REGEXP ).and_return( :jpg_imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :jpg_imgdata_io, jpg_art_hash )

			StringIO.should_receive( :new ).with( PNG_MAGIC_REGEXP ).and_return( :png_imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :png_imgdata_io, png_art_hash )

			@filter.handle_request( @request, @response )
		end


		it "extracts album art from an uploaded mp3 (single, APIC)" do
			testdata = MP3_DATADIR + 'APIC-1-image.mp3'
			io = testdata.open
			art_hash = {
				:format => 'image/jpeg',
				:extent => 7369,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}

			@request.stub!( :each_body ).and_yield( io, @request_metadata )
			@request.stub!( :append_metadata_for )
			StringIO.should_receive( :new ).with( JPEG_MAGIC_REGEXP ).and_return( :imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :imgdata_io, art_hash )

			@filter.handle_request( @request, @response )
		end


		it "extracts album art from an uploaded mp3 (multiple, APIC)" do
			testdata = MP3_DATADIR + 'APIC-2-images.mp3'
			io = testdata.open
			jpg_art_hash = {
				:format => 'image/jpeg',
				:extent => 7369,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}
			png_art_hash = {
				:format => 'image/png',
				:extent => 18031,
				:title  => 'Album art for Tim Reilly - (unknown)',
				:relation => 'album-art'
			}

			@request.stub!( :each_body ).and_yield( io, @request_metadata )
			@request.stub!( :append_metadata_for )

			StringIO.should_receive( :new ).with( JPEG_MAGIC_REGEXP ).and_return( :jpg_imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :jpg_imgdata_io, jpg_art_hash )

			StringIO.should_receive( :new ).with( PNG_MAGIC_REGEXP ).and_return( :png_imgdata_io )
			@request.should_receive( :append_related_resource ).with( io, :png_imgdata_io, png_art_hash )

			@filter.handle_request( @request, @response )
		end
	end
end

# vim: set nosta noet ts=4 sw=4:

