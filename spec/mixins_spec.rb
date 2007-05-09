#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'stringio'
require 'spec/runner'
require "thingfish/mixins"

describe "A class which has mixed in Loggable" do
	before(:each) do
		@logfile = StringIO.new('')
		ThingFish.logger = Logger.new( @logfile )

		@test_class = Class.new do
			include ThingFish::Loggable

			def log_test_message( level, msg )
				self.log.send( level, msg )
			end
			
			def test_log_request( request )
				self.log_request( request )
			end
		end
		@obj = @test_class.new
	end


	it "is able to output to the log via its #log method" do
		@obj.log_test_message( :debug, "debugging message" )
		@logfile.rewind
		@logfile.read.should =~ /debugging message/
	end
	
end


describe "A handler class which has mixed in StaticResources" do
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResources
		end
	end


	it "has a 'static_resources_dir' class method" do
		@test_class.should respond_to( :static_resources_dir)
	end

	it "has a 'static_resources_dir' of 'static' by default" do
		@test_class.static_resources_dir.should == 'static'
	end
end

describe "A handler class which has mixed in StaticResources and set the static resources dir" do
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResources
			static_resources_dir "static-content"
		end
	end


	it "should have the specified static_resources_dir" do
		@test_class.static_resources_dir.should == 'static-content'
	end
end

describe "An instance of a handler class which has mixed in StaticResources" do
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResources
			static_resources_dir "static-content"
		end
		@test_handler = @test_class.new
	end


	it "registers another handler at its own location when registered" do
		classifier = Mongrel::URIClassifier.new
		classifier.register( '/glah', @test_handler )

		listener = mock( "listener", :null_object => true )
		listener.should_receive( :classifier ).and_return( classifier )
		listener.should_receive( :register ).with( '/glah', duck_type(:request_begins, :process) )

		@test_handler.listener = listener
	end
end

describe "A class which has mixed in AbstractClass" do
	before(:each) do
		@test_class = Class.new do
			include ThingFish::AbstractClass
		end
	end


	it "won't have a public ::new method" do
		lambda {
			@test_class.new
		}.should raise_error( NoMethodError, /private/ )
	end
	
end


describe "An instance of a class derived from one which has mixed in AbstractClass " +
	"and defined virtual methods" do
	before(:each) do
		@base_class = Class.new do
			include ThingFish::AbstractClass
			virtual :test_method
		end
		@subclass = Class.new( @base_class )
		@instance = @subclass.new
	end


	it "raises a NotImplementedError when unimplemented API methods are called" do
		lambda {
			@instance.test_method
		}.should raise_error( NotImplementedError, /does not provide an implementation of/ )
	end
	
end


describe Numeric, " after mixing in ThingFish::NumericConstantMethods" do

	SECONDS_IN_A_MINUTE    = 60
	SECONDS_IN_AN_HOUR     = SECONDS_IN_A_MINUTE * 60
	SECONDS_IN_A_DAY       = SECONDS_IN_AN_HOUR * 24
	SECONDS_IN_A_WEEK      = SECONDS_IN_A_DAY * 7
	SECONDS_IN_A_FORTNIGHT = SECONDS_IN_A_WEEK * 2
	SECONDS_IN_A_MONTH     = SECONDS_IN_A_DAY * 30
	SECONDS_IN_A_YEAR      = Integer( SECONDS_IN_A_DAY * 365.25 )

	it "can calculate the number of seconds for various units of time" do
		1.second.should == 1
		14.seconds.should == 14
		
		1.minute.should == SECONDS_IN_A_MINUTE
		18.minutes.should == SECONDS_IN_A_MINUTE * 18
		
		1.hour.should == SECONDS_IN_AN_HOUR
		723.hours.should == SECONDS_IN_AN_HOUR * 723
		
		1.day.should == SECONDS_IN_A_DAY
		3.days.should == SECONDS_IN_A_DAY * 3
		
		1.week.should == SECONDS_IN_A_WEEK
		28.weeks.should == SECONDS_IN_A_WEEK * 28
		
		1.fortnight.should == SECONDS_IN_A_FORTNIGHT
		31.fortnights.should == SECONDS_IN_A_FORTNIGHT * 31
		
		1.month.should == SECONDS_IN_A_MONTH
		67.months.should == SECONDS_IN_A_MONTH * 67
		
		1.year.should == SECONDS_IN_A_YEAR
		13.years.should == SECONDS_IN_A_YEAR * 13
	end


	it "can calulate various time offsets" do
		starttime = Time.now
		
		1.second.after( starttime ).should == starttime + 1
		18.seconds.from_now.should be_close( starttime + 18, 10 )

		1.second.before( starttime ).should == starttime - 1
		3.hours.ago.should be_close( starttime - 10800, 10 )
	end
	


	BYTES_IN_A_KILOBYTE = 1024
	BYTES_IN_A_MEGABYTE = BYTES_IN_A_KILOBYTE * 1024
	BYTES_IN_A_GIGABYTE = BYTES_IN_A_MEGABYTE * 1024
	BYTES_IN_A_TERABYTE = BYTES_IN_A_GIGABYTE * 1024
	BYTES_IN_A_PETABYTE = BYTES_IN_A_TERABYTE * 1024
	BYTES_IN_AN_EXABYTE = BYTES_IN_A_PETABYTE * 1024
	
	it "can calulate the number of bytes for various data sizes" do
		1.byte.should == 1
		4.bytes.should == 4
		
		1.kilobyte.should == BYTES_IN_A_KILOBYTE
		22.kilobytes.should == BYTES_IN_A_KILOBYTE * 22

		1.megabyte.should == BYTES_IN_A_MEGABYTE
		116.megabytes.should == BYTES_IN_A_MEGABYTE * 116
		
		1.gigabyte.should == BYTES_IN_A_GIGABYTE
		14.gigabytes.should == BYTES_IN_A_GIGABYTE * 14
		
		1.terabyte.should == BYTES_IN_A_TERABYTE
		88.terabytes.should == BYTES_IN_A_TERABYTE * 88
		
		1.petabyte.should == BYTES_IN_A_PETABYTE
		34.petabytes.should == BYTES_IN_A_PETABYTE * 34
		
		1.exabyte.should == BYTES_IN_AN_EXABYTE
		6.exabytes.should == BYTES_IN_AN_EXABYTE * 6
	end
	

end