#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}


begin
	require 'pathname'
	require 'logger'
	require 'spec/runner'
	require 'stringio'
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

BOUNDARY = 'sillyBoundary'

unless defined?( SPECDIR )
	SPECDIR = Pathname.new( __FILE__ ).dirname
	DATADIR = SPECDIR + 'data'
end


### Create a stub request prepopulated with HTTP headers and form data
def load_form( filename )
	datafile = DATADIR + filename
	return datafile.open
end


describe ThingFish::MultipartMimeParser do

	before( :all ) do
		ThingFish.logger.level = Logger::FATAL
	end
	

	before( :each ) do
		@parser = ThingFish::MultipartMimeParser.new
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
		meta[:extent].should == 482
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
		meta[:extent].should == 482
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
		meta[:extent].should == 482
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
			tmpfile.read.should =~ JPEG_MAGIC
		end
		
		titles = files.values.collect {|v| v[:title]}
		titles.should include('Photo 3.jpg')
		titles.should include('grass2.jpg')

		types = files.values.collect {|v| v[:format]}
		types.should == ['image/jpeg', 'image/jpeg']

		sizes = files.values.collect {|v| v[:extent]}
		sizes.should include(439259)
		sizes.should include(82145)
	end
	
end

# vim: set nosta noet ts=4 sw=4:
