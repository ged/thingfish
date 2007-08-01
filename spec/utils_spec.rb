#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

begin
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/helpers'
	require 'spec/lib/constants'
	
	require "thingfish/utils"
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestHelpers


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Table do
	before( :each ) do
		@table = ThingFish::Table.new
	end
	

	it "allows setting/fetching case-insensitively" do
		
		@table['Accept'] = :accept
		@table['USER-AGENT'] = :user_agent
		@table[:accept_encoding] = :accept_encoding
		
		@table['accept'].should == :accept
		@table['ACCEPT'].should == :accept
		@table['Accept'].should == :accept
		@table[:accept].should == :accept
		
		@table['USER-AGENT'].should == :user_agent
		@table['User-Agent'].should == :user_agent
		@table['user-agent'].should == :user_agent
		@table[:user_agent].should == :user_agent
		
		@table['ACCEPT-ENCODING'].should == :accept_encoding
		@table['Accept-Encoding'].should == :accept_encoding
		@table['accept-encoding'].should == :accept_encoding
		@table[:accept_encoding].should == :accept_encoding
	end
	
	it "should assign a new value when appending to a non-existing key" do
		@table.append( 'indian-meal', 'pinecones' )
		@table['Indian-Meal'].should == 'pinecones'
	end
	
	
	it "should create an array value and append when appending to an existing key" do
		@table[:indian_meal] = 'pork sausage'
		@table.append( 'Indian-MEAL', 'pinecones' )
		@table['Indian-Meal'].should have(2).members
		@table['Indian-Meal'].should include('pinecones')
		@table['Indian-Meal'].should include('pork sausage')
	end
	
	
	it "it should combine pairs in the intial hash whose keys normalize to the " +
		"same thing into an array value" do

		table = ThingFish::Table.new({ :bob => :dan, 'Bob' => :dan_too })
		
		table[:bob].should have(2).members
		table['bob'].should include( :dan )
		table['Bob'].should include( :dan_too )
	end
	
end