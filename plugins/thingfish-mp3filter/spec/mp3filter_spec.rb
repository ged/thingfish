#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
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

	TEST_TITLE  = "Meatphone"
	TEST_ARTIST = "The Artist Formerly Known as Pork"
	TEST_ALBUM  = "Lung Bacon"

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
		extracted_metadata = {}
		
		@request.should_receive( :metadata ).and_return({ @io => extracted_metadata })
		@mp3info.should_receive( :samplerate ).and_return( 44000 )
		@mp3info.should_receive( :bitrate ).and_return( 128 )
		@mp3info.should_receive( :vbr ).and_return( true )
		
		@id3tag.should_receive( :title ).and_return( TEST_TITLE )
		@id3tag.should_receive( :artist ).and_return( TEST_ARTIST )
		@id3tag.should_receive( :album ).and_return( TEST_ALBUM )
		
		@filter.handle_request( @request, @response )
		
		extracted_metadata.should have(10).members
		extracted_metadata[:mp3_artist].should == TEST_ARTIST
		extracted_metadata[:mp3_title].should == TEST_TITLE
		extracted_metadata[:mp3_album].should == TEST_ALBUM
	end

	
	it "extracts MP3 metadata from ID3v2 (v2.2.0) tags of uploaded MP3s"
	it "ignores all non-mp3 uploads"
	it "ignores non-POST requests"
	
end

# vim: set nosta noet ts=4 sw=4:
