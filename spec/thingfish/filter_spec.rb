#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants


class TestFilter < ThingFish::Filter
end



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::Filter do
	before( :each ) do
		@filter = ThingFish::Filter.create( 'test', {} )
	end


	it "raises a NotImplementedError for request filter operations" do
		lambda do
			@filter.handle_request( :request, :response )
		end.should raise_error( NotImplementedError, /#handle_request/i)
	end


	it "raises a NotImplementedError for response filter operations" do
		lambda do
			@filter.handle_response( :response, :request )
		end.should raise_error( NotImplementedError, /#handle_response/i)
	end


	it "handles a single wildcard mimetype" do
		@filter.handled_types.should have(1).members
		@filter.handled_types.first.should be_an_instance_of( ThingFish::AcceptParam )
	end


	it "accepts all types by default" do
		@filter.accepts?( 'image/png' ).should be_true()
	end


	it "knows what its plugin name is" do
		@filter.class.plugin_name.should == 'test'
	end

end

# vim: set nosta noet ts=4 sw=4:
