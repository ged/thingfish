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
	require 'thingfish/acceptparam'
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

describe ThingFish::AcceptParam do

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
		'IMAGE/pNg' =>
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
			rval = ThingFish::AcceptParam.parse( hdr )

			rval.should be_an_instance_of( ThingFish::AcceptParam )
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
			rval = ThingFish::AcceptParam.parse( '*/*; q=18' )
		}.should_not raise_error()

		rval.should be_an_instance_of( ThingFish::AcceptParam )
		rval.qvalue.should == 1.0
	end


	it "rejects invalid Accept header values" do
		lambda {
			ThingFish::AcceptParam.parse( 'porksausage' )
		}.should raise_error()
	end


	it "can represent itself in a human-readable object format" do
		header = "text/html; q=0.9; level=2"
		acceptparam = ThingFish::AcceptParam.parse( header )
		acceptparam.inspect.should =~ %r{AcceptParam.*text/html.*q=0.9}
	end


	it "can represent itself as an Accept header" do
		header = "text/html;q=0.9;level=2"
		acceptparam = ThingFish::AcceptParam.parse( header )
		acceptparam.to_s.should == header
	end


	it "can compare and sort on specificity" do
		header = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9," +
			     "text/html;q=0.9;level=1,text/plain;q=0.8,image/png,*/*;q=0.5"
		params = header.split(/\s*,\s*/).collect {|par|
			ThingFish::AcceptParam.parse( par )
		}.sort

		params[0].to_s.should == 'application/xhtml+xml;q=1.0'
		params[1].to_s.should == 'application/xml;q=1.0'
		params[2].to_s.should == 'image/png;q=1.0'
		params[3].to_s.should == 'text/xml;q=1.0'
		params[4].to_s.should == 'text/html;q=0.9;level=1'
		params[5].to_s.should == 'text/html;q=0.9'
		params[6].to_s.should == 'text/plain;q=0.8'
		params[7].to_s.should == '*/*;q=0.5'
	end


	it "can be compared against strings" do
		specific_param = ThingFish::AcceptParam.parse( CONFIGURED_HTML_MIMETYPE )
		type_wildcard_param = ThingFish::AcceptParam.parse( '*/*' )
		subtype_wildcard_param = ThingFish::AcceptParam.parse( 'image/*' )

		( specific_param =~ CONFIGURED_HTML_MIMETYPE ).should be_true()
		( specific_param =~ 'image/png' ).should be_false()

		( subtype_wildcard_param =~ 'image/png' ).should be_true()
		( subtype_wildcard_param =~ 'image/jpeg' ).should be_true()
		( subtype_wildcard_param =~ 'text/plain' ).should be_false()
	end
end

# vim: set nosta noet ts=4 sw=4:
