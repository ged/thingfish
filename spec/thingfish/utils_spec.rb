#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'spec'
require 'spec/lib/helpers'
require 'spec/lib/constants'

require 'stringio'

require 'thingfish/utils'


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Table do
	include ThingFish::SpecHelpers


	before( :all ) do
		setup_logging( :fatal )
	end

	before( :each ) do
		@table = ThingFish::Table.new
	end

	after( :all ) do
		reset_logging()
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
		@table.append( 'indian-meal' => 'pinecones' )
		@table['Indian-Meal'].should == 'pinecones'
	end


	it "should create an array value and append when appending to an existing key" do
		@table[:indian_meal] = 'pork sausage'
		@table.append( 'Indian-MEAL' => 'pinecones' )
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

		table.append( 'x-ice-cream-flavor' => 'banana' )

		table.to_s.should =~ %r{Accept: text/html\r\n}
		table.to_s.should =~ %r{X-Ice-Cream-Flavor: mango\r\n}
		table.to_s.should =~ %r{X-Ice-Cream-Flavor: banana\r\n}
	end


	it "merges other Tables" do
		othertable = ThingFish::Table.new

		@table['accept'] = 'thing'
		@table['cookie'] = 'chocolate chip'

		othertable['cookie'] = 'peanut butter'

		ot = @table.merge( othertable )
		ot['accept'].should == 'thing'
		ot['cookie'].should == 'peanut butter'
	end


	it "merges hashes after normalizing keys" do
		@table['accept'] = 'thing'
		@table['cookie-flavor'] = 'chocolate chip'

		hash = { 'CookiE_FLAVOR' => 'peanut butter' }

		ot = @table.merge( hash )
		ot['accept'].should == 'thing'
		ot['cookie-flavor'].should == 'peanut butter'
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


	it "provides an implementation of #each that returns keys as HTTP headers" do
		@table.append( 'thai_food' => 'normally good' )
		@table.append( :with_absinthe => 'questionable' )
		@table.append( 'A_Number_of_SOME_sort' => 2 )
		@table.append( 'thai_food' => 'seldom hot enough' )

		values = []
		@table.each_header do |header, value|
			values << [ header, value ]
		end

		values.flatten.should have(8).members
		values.transpose[0].should include( 'Thai-Food', 'With-Absinthe', 'A-Number-Of-Some-Sort' )
		values.transpose[1].should include( 'normally good', 'seldom hot enough', 'questionable', '2' )
	end
end


