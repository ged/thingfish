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


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Table do
	include ThingFish::TestHelpers
	
	
	before( :all ) do
		setup_logging()
	end
	
	before( :each ) do
		@table = ThingFish::Table.new
	end
	
	after( :all ) do
		ThingFish.reset_logger
	end
	
	

	it "allows setting/fetching case-insensitively" do
		
		@table['Accept'] = :accept
		@table['USER-AGENT'] = :user_agent
		@table[:accept_encoding] = :accept_encoding
		@table.accept_encoding = :accept_encoding
				
		@table['accept'].should == :accept
		@table['ACCEPT'].should == :accept
		@table['Accept'].should == :accept
		@table[:accept].should == :accept
		@table.accept.should == :accept
	
		@table['USER-AGENT'].should == :user_agent
		@table['User-Agent'].should == :user_agent
		@table['user-agent'].should == :user_agent
		@table[:user_agent].should == :user_agent
		@table.user_agent.should == :user_agent
		
		@table['ACCEPT-ENCODING'].should == :accept_encoding
		@table['Accept-Encoding'].should == :accept_encoding
		@table['accept-encoding'].should == :accept_encoding
		@table[:accept_encoding].should == :accept_encoding
		@table.accept_encoding.should == :accept_encoding
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
		table['Bob'].should include( :dan )
		table['bob'].should include( :dan_too )
	end
	
	
	it "creates RFC822-style header lines when cast to a String" do
		table = ThingFish::Table.new({
			:accept => 'text/html',
			'x-ice-cream-flavor' => 'mango'
		})
		
		table.append( 'x-ice-cream-flavor', 'banana' )
		
		table.to_s.should =~ %r{Accept: text/html\r\n}
		table.to_s.should =~ %r{X-Ice-Cream-Flavor: mango\r\n}
		table.to_s.should =~ %r{X-Ice-Cream-Flavor: banana\r\n}
	end


	it "provides a case-insensitive merge function" do
		othertable = ThingFish::Table.new
		
		@table['accept'] = 'thing'
		@table['cookie'] = 'chocolate chip'

		othertable['cookie'] = 'peanut butter'

		ot = @table.merge( othertable )
		ot['accept'].should == 'thing'
		ot['cookie'].should have(2).members
		ot['cookie'].should include('chocolate chip')
		ot['cookie'].should include('peanut butter')
	end
	

	it "dupes its inner hash when duped" do
		newtable = @table.dup
		
		newtable['idkfa'] = 'god'
		@table.should_not include( 'idkfa' )
		@table.should be_empty()
	end


	it "provides a case-insensitive version of the #values_at" do
		@table['uuddlrlrbas']      = 'contra_rules'
		@table['idspispopd']       = 'ghosty'
		@table['porntipsguzzardo'] = 'cha-ching'

		results = @table.values_at( :idspispopd, 'PornTipsGuzzARDO' )
		results.should include( 'ghosty' )
		results.should include( 'cha-ching' )
		results.should_not include( 'contra_rules' )
	end

end


