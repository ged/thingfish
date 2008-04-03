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
		:mp3_frequency => 44000,
		:mp3_bitrate   => 128,
		:mp3_vbr       => true,

		:mp3_tracknum  => TEST_TRACKNUM,
		:mp3_title     => TEST_MP3_TITLE,
		:mp3_artist    => TEST_ARTIST,
		:mp3_album     => TEST_ALBUM,
		:mp3_comments  => TEST_COMMENTS,
		:mp3_year      => TEST_YEAR,
		:mp3_genre     => TEST_GENRE,
	}
	

	before( :each ) do
	    @filter = ThingFish::Filter.create( 'mp3' )
	
		@io = StringIO.new( TEST_CONTENT )
		@io.stub!( :path ).and_return( :a_dummy_path )
		@response = stub( "response object" )

		@request_metadata = { :format => 'audio/mpeg' }
		@request = mock( "request object" )
		@request.stub!( :http_method ).and_return( 'POST' )
		@request.stub!( :each_body ).and_yield( @io, @request_metadata )

		@mp3info = mock( "MP3 info object", :null_object => true )
		Mp3Info.stub!( :new ).and_return( @mp3info )
		@id3tag = mock( "ID3 tag object", :null_object => true )
		@mp3info.stub!( :tag ).and_return( @id3tag )
	end
	
	
	### Shared behaviors
	it_should_behave_like "A Filter"
	

	### Filter-specific tests
	
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
		normalized_values[:mp3_album] = "(unknown)"
		
		@request.should_receive( :append_metadata_for ).with( @io, normalized_values )
		@filter.handle_request( @request, @response )
	end
	
	
	it "ignores non-POST requests" do
		@request.should_receive( :http_method ).
			at_least( :once ).
			and_return( 'GET' )
		@request.should_not_receive( :each_body )
		
		@filter.handle_request( @request, @response )
	end
	
end

# vim: set nosta noet ts=4 sw=4:
