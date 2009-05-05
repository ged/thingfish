#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/response'
	require 'thingfish/exceptions'
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

describe ThingFish::Response do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end
	
	before( :each ) do
		@config = stub( "ThingFish config object" )
		@response = ThingFish::Response.new( 1.1, @config )
	end


	it "has some default headers" do
		@response.headers['Server'] == SERVER_SOFTWARE_DETAILS
	end

	it "can be reset to a pristine state" do
		@response.body << "Some stuff we want to get rid of later"
		@response.headers['x-lunch-packed-by'] = 'Your Mom'
		@response.status = HTTP::OK

		@response.reset

		@response.should_not be_handled()
		@response.body.should == ''
		@response.headers.should have(1).keys
	end


	it "can find the length of its body if it's a String" do
		test_body = 'A string full of stuff'
		@response.body = test_body

		@response.get_content_length.should == test_body.length
	end

	it "knows that it has been handled even if the status is set to NOT_FOUND" do
		@response.status = HTTP::NOT_FOUND
		@response.should be_handled()
	end

	it "knows if it has not yet been handled" do
		@response.should_not be_handled()
		@response.status = HTTP::OK
		@response.should be_handled()
	end


	it "knows what category of response it is" do
		@response.status = HTTP::CREATED
		@response.status_category.should == 2

		@response.status = HTTP::NOT_ACCEPTABLE
		@response.status_category.should == 4
	end


	it "knows if its status indicates it is an informational response" do
		@response.status = HTTP::PROCESSING
		@response.status_category.should == 1
		@response.status_is_informational?.should == true
	end


	it "knows if its status indicates it is a successful response" do
		@response.status = HTTP::ACCEPTED
		@response.status_category.should == 2
		@response.status_is_successful?.should == true
	end


	it "knows if its status indicates it is a redirected response" do
		@response.status = HTTP::SEE_OTHER
		@response.status_category.should == 3
		@response.status_is_redirect?.should == true
	end


	it "knows if its status indicates there was a client error" do
		@response.status = HTTP::GONE
		@response.status_category.should == 4
		@response.status_is_clienterror?.should == true
	end


	it "knows if its status indicates there was a server error" do
		@response.status = HTTP::VERSION_NOT_SUPPORTED
		@response.status_category.should == 5
		@response.status_is_servererror?.should == true
	end


	it "knows what the response content type is" do
		headers = mock( 'headers' )
		@response.stub!( :headers ).and_return( headers )

		headers.should_receive( :[] ).
			with( :content_type ).
			and_return( 'text/erotica' )

		@response.content_type.should == 'text/erotica'
	end


	it "can modify the response content type" do
		headers = mock( 'headers' )
		@response.stub!( :headers ).and_return( headers )

		headers.should_receive( :[]= ).
			with( :content_type, 'image/nude' )

		@response.content_type = 'image/nude'
	end


	it "can find the length of its body if it's an IO" do
		test_body_content = 'A string with some stuff in it'
		test_body = StringIO.new( test_body_content )
		@response.body = test_body

		@response.get_content_length.should == test_body_content.length
	end


	it "raises a descriptive error message if it can't get the body's length" do
		@response.body = Object.new

		lambda {
			@response.get_content_length
		}.should raise_error( ThingFish::ResponseError, /content length/i )
	end


	it "has a scratchspace for passing data between handlers and filters" do
		@response.data.should be_an_instance_of( ThingFish::Table )
	end


	it "can build a valid HTTP status line for its status" do
		@response.status = HTTP::SEE_OTHER
		@response.status_line.should == "HTTP/1.1 303 See Other"
	end


	it "can build a valid HTTP header string from the response headers" do
		headers = mock( 'headers' )
		@response.stub!( :headers ).and_return( headers )

		headers.should_receive( :[] ).with( :content_length ).and_return( nil )
		headers.should_receive( :[]= ).with( :content_length, an_instance_of(Fixnum) )
		headers.should_receive( :[] ).with( :date ).and_return( nil )
		headers.should_receive( :[]= ).with( :date, VALID_HTTPDATE )
		headers.should_receive( :to_s ).and_return( :the_headers )

		@response.header_data.should == :the_headers
	end


	it "has pipelining disabled by default" do
		@response.should_not be_keepalive()
	end
	
	
	it "has pipelining disabled if it's explicitly disabled" do
		@response.keepalive = false
		@response.should_not be_keepalive()
	end
	
	
	it "can be set to allow pipelining" do
		@response.keepalive = true
		@response.should be_keepalive()
	end
	
end

# vim: set nosta noet ts=4 sw=4:
