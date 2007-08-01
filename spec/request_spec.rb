#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	
	libdir = basedir + "lib"
	
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/request'
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

describe ThingFish::Request do
	
	it "wraps and delegates to a mongrel request object" do
		params = {
			'HTTP_ACCEPT' => 'Accept',
		}
		
		mongrel_request = mock( "mongrel request", :null_object => true )
		request = ThingFish::Request.new( mongrel_request )
		
		mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		request.headers['accept'].should == 'Accept'
		request.headers['Accept'].should == 'Accept'
		request.headers['ACCEPT'].should == 'Accept'
		
	end
	
	
	it "extracts HTTP headers as simple headers from its mongrel request"

	it "parses the 'Accept' header into one or more AcceptParam structs"
	
	it "provides an interface to parse multipart documents"
    
end


# vim: set nosta noet ts=4 sw=4:
