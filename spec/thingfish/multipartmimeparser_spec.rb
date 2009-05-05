#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}


begin
	require 'pathname'
	require 'logger'
	require 'spec'
	require 'spec/lib/helpers'
	require 'stringio'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/multipartmimeparser'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::MultipartMimeParser do
	include ThingFish::SpecHelpers

	BOUNDARY = 'sillyBoundary'
	MIMEPARSER_SPECDIR = Pathname.new( __FILE__ ).dirname.parent
	MIMEPARSER_DATADIR = MIMEPARSER_SPECDIR + 'data'

	### Create a stub request prepopulated with HTTP headers and form data
	def load_form( filename )
		datafile = MIMEPARSER_DATADIR + filename
		return datafile.open( 'rb' )
	end


	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
		@tmpdir = make_tempdir()
		@parser = ThingFish::MultipartMimeParser.new( @tmpdir )
	end

	after( :all ) do
		@tmpdir.rmtree
		ThingFish.reset_logger
	end



	it "should error if the initial boundary can't be found" do
		socket = load_form( "testform_bad.form" )

		lambda {
			@parser.parse( socket, BOUNDARY )
		}.should raise_error( ThingFish::RequestError, /^No initial boundary/ )
	end


	it "should error if headers can't be found" do
		socket = load_form( "testform_badheaders.form" )

		lambda {
			@parser.parse( socket, BOUNDARY )
		}.should raise_error( ThingFish::RequestError, /^EOF while searching for headers/ )
	end


	it "raises an error when the document is truncated inside an extraneous form field" do
		socket = load_form( "testform_truncated_metadata.form" )

		lambda {
			@parser.parse( socket, BOUNDARY )
		}.should raise_error( ThingFish::RequestError, /^truncated MIME document/i )
	end


	it "parses form fields that start with 'thingfish-metadata-' into the metadata hash" do
		socket = load_form( "testform_metadataonly.form" )

		files, metadata = @parser.parse( socket, BOUNDARY )

		files.should be_empty

		metadata.should have(4).keys
		metadata.keys.should_not include( :'x-livejournal-entry' )
	end


	it "parses the file from a simple upload" do
		socket = load_form( "singleupload.form" )
		files, metadata = @parser.parse( socket, BOUNDARY )

		files.should be_an_instance_of( Hash )
		metadata.should be_an_instance_of( Hash )
		metadata.should be_empty

		files.should have(1).keys
		file = files.keys.first
		meta = files.values.first

		meta.should be_an_instance_of( Hash )
		meta[:title].should == 'testfile.rtf'
		meta[:extent].should == 480
		meta[:format].should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end

	it "strips full paths from upload filenames (e.g., from MSIE)" do
		socket = load_form( "testform_msie.form" )
		files, metadata = @parser.parse( socket, BOUNDARY )

		files.should be_an_instance_of( Hash )
		metadata.should be_an_instance_of( Hash )
		metadata.should be_empty

		files.should have(1).keys
		file = files.keys.first
		meta = files.values.first

		meta.should be_an_instance_of( Hash )
		meta[:title].should == 'testfile.rtf'
		meta[:extent].should == 480
		meta[:format].should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end

	it "extracts metadata information from fields whose name begins with 'thingfish-metadata-'" do
		socket = load_form( "testform_multivalue.form" )
		files, metadata = @parser.parse( socket, BOUNDARY )

		files.should be_an_instance_of( Hash )
		metadata.should be_an_instance_of( Hash )
		metadata.should have(3).keys

		metadata[:pork].should be_an_instance_of( Array )
		metadata[:pork].should have(2).members
		metadata[:pork].should include( 'zoot' )
		metadata[:pork].should include( 'fornk' )

		metadata[:namespace].should == 'testing'
		metadata[:rating].should == '5'

		# (Empty upload fields are ignored)
		files.should have(1).keys
		file = files.keys.first
		meta = files.values.first

		meta.should be_an_instance_of( Hash )
		meta[:title].should == 'testfile.rtf'
		meta[:extent].should == 480
		meta[:format].should == 'application/rtf'

		file.open
		file.read.should =~ /screaming.+anguish.+sirens/
	end

	JPEG_MAGIC = /^\xff\xd8/

	it "parses the files from multiple uploads" do
		socket = load_form( "2_images.form" )
		files, metadata = @parser.parse( socket, BOUNDARY )

		files.should be_an_instance_of( Hash )
		metadata.should be_an_instance_of( Hash )

		files.should have(2).keys
		files.keys.each do |tmpfile|
			tmpfile.open
			tmpfile.set_encoding( 'ascii-8bit' ) if tmpfile.respond_to?( :set_encoding )
			tmpfile.read.should =~ JPEG_MAGIC
		end

		titles = files.values.collect {|v| v[:title]}
		titles.should include('Photo 3.jpg', 'grass2.jpg')

		types = files.values.collect {|v| v[:format]}
		types.should == ['image/jpeg', 'image/jpeg']

		sizes = files.values.collect {|v| v[:extent]}
		sizes.should include(439257, 82143)
	end

end

# vim: set nosta noet ts=4 sw=4:
