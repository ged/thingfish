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
	
	before( :each ) do
		@mongrel_request = mock( "mongrel request", :null_object => true )
		@request = ThingFish::Request.new( @mongrel_request )
	end

	
	it "wraps and delegates to a mongrel request object" do
		@mongrel_request.should_receive( :body ).and_return( :the_body )
		@request.body.should == :the_body
	end
	
	
	it "extracts HTTP headers as simple headers from its mongrel request" do
		params = {
			'HTTP_ACCEPT' => 'Accept',
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.headers['accept'].should == 'Accept'
		@request.headers['Accept'].should == 'Accept'
		@request.headers['ACCEPT'].should == 'Accept'
	end
	
	
	it "parses the 'Accept' header into one or more AcceptParam structs" do
		params = {
			# 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'
			'HTTP_ACCEPT' => TEST_ACCEPT_HEADER,
		}
		
		@mongrel_request.should_receive( :params ).at_least(:once).and_return( params )
		
		@request.accepted_types.should have(3).members
		@request.accepted_types[0].mediatype.should == 'application/x-yaml'
		@request.accepted_types[1].mediatype.should == 'application/json'
		@request.accepted_types[2].mediatype.should == 'text/xml'
	end
	
	it "knows whether it has a multipart body or not" 
	it "provides an interface to parse multipart documents" 
    
end


describe ThingFish::Request::AcceptParam do

	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	ValidHeaders = {
		'*/*' =>
			{:type => nil, :subtype => nil, :qval => 1.0},
		'*/*; q=0.1' =>
			{:type => nil, :subtype => nil, :qval => 0.1},
		'*/*;q=0.1' =>
			{:type => nil, :subtype => nil, :qval => 0.1},
		'image/*' =>
			{:type => 'image', :subtype => nil, :qval => 1.0},
		'image/*; q=0.18' =>
			{:type => 'image', :subtype => nil, :qval => 0.18},
		'image/*;q=0.4' =>
			{:type => 'image', :subtype => nil, :qval => 0.4},
		'image/*;q=0.9; porn=0; anseladams=1' =>
			{:type => 'image', :subtype => nil, :qval => 0.9,
				:extensions => %w[anseladams=1 porn=0]},
		'image/png' =>
			{:type => 'image', :subtype => 'png', :qval => 1.0},
		'application/x-porno' =>
			{:type => 'application', :subtype => 'x-porno', :qval => 1.0},
		'image/png; q=0.2' =>
			{:type => 'image', :subtype => 'png', :qval => 0.2},
		'image/x-giraffes;q=0.2' =>
			{:type => 'image', :subtype => 'x-giraffes', :qval => 0.2},
		'example/pork;    headcheese=0;withfennel=1' =>
			{:type => 'example', :subtype => 'pork', :qval => 1.0,
				:extensions => %w[headcheese=0 withfennel=1]},
		'model/vnd.moml+xml' =>
			{:type => 'model', :subtype => 'vnd.moml+xml', :qval => 1.0},
		'model/parasolid.transmit.binary; q=0.2' =>
			{:type => 'model', :subtype => 'parasolid.transmit.binary',
				:qval => 0.2},
		'image/png; q=0.2; compression=1' =>
			{:type => 'image', :subtype => 'png', :qval => 0.2,
				:extensions => %w[compression=1]},
	}


	it "parses valid Accept header values" do
		ValidHeaders.each do |hdr, expectations|
			rval = ThingFish::Request::AcceptParam.parse( hdr )
		
			rval.should be_an_instance_of( ThingFish::Request::AcceptParam )
			rval.type.should == expectations[:type]
			rval.subtype.should == expectations[:subtype]
			rval.qvalue.should == expectations[:qval]
			if expectations[:extensions]
				expectations[:extensions].each do |ext|
					rval.extensions.should include(ext)
				end
			end
		end
	end

	it "is lenient (but warns) about invalid qvalues" do
		rval = nil
		lambda {
			rval = ThingFish::Request::AcceptParam.parse( '*/*; q=18' )
		}.should_not raise_error()
		
		rval.should be_an_instance_of( ThingFish::Request::AcceptParam )
		rval.qvalue.should == 1.0
	end
	
	
	it "rejects invalid Accept header values" do
		lambda {
			ThingFish::Request::AcceptParam.parse( 'porksausage' )
		}.should raise_error()
	end
	
	
	
end

# vim: set nosta noet ts=4 sw=4:
