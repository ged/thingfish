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
	
	require "thingfish/mixins"
	require "thingfish/handler"
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::SpecHelpers


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::Loggable, " (class)" do
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


describe ThingFish::StaticResourcesHandler, " which has been mixed into a class" do
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResourcesHandler
		end
	end


	it "has a 'static_resources_dir' class method" do
		@test_class.should respond_to( :static_resources_dir)
	end

	it "has a 'static_resources_dir' of 'static' by default" do
		@test_class.static_resources_dir.should == 'static'
	end
end

describe ThingFish::StaticResourcesHandler, 
	" which has mixed into a handler class that has set the static resources dir" do
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResourcesHandler
			static_resources_dir "static-content"
		end
	end


	it "should have the specified static_resources_dir" do
		@test_class.static_resources_dir.should == 'static-content'
	end
end

describe ThingFish::StaticResourcesHandler, 
	" which has been mixed into an instance of a handler class" do
	
	before(:each) do
		@test_class = Class.new( ThingFish::Handler ) do
			include ThingFish::StaticResourcesHandler
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

describe ThingFish::ResourceLoader do
	it "adds a #get_resource method to including classes" do
		klass = Class.new { include ThingFish::ResourceLoader }
		obj = klass.new
		obj.should respond_to( :get_resource )
	end
end

describe "A class which has mixed in ThingFish::ResourceLoader" do
	
	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL

		@resdir = make_tempdir()
		@resdir.mkpath
		
		@tmpfile = Tempfile.new( 'test.txt', @resdir )
		@tmpfile.print( TEST_RESOURCE_CONTENT )
		@tmpfile.close
		@tmpname = Pathname.new( @tmpfile.path ).basename
	
		@klass = Class.new {
			include ThingFish::ResourceLoader
			public :get_resource, :resource_exists?, :resource_directory?
		}
	end
	
	after(:all) do
		@resdir.rmtree
		ThingFish.reset_logger
	end

	before(:each) do
		@obj = @klass.new( :resource_dir => @resdir )
	end

	it "should know what its resource directory is" do
		@obj.resource_dir.should == @resdir
	end

	it "is able to load stuff from its resources dir" do
	    @obj.get_resource( @tmpname ).should == TEST_RESOURCE_CONTENT
	end
	
	it "can test for the existance of a resource" do
		@obj.resource_exists?( @tmpname ).should be_true()
	end

	it "can test for the existance of a resource directory" do
		@obj.resource_directory?( @tmpname ).should be_false()
		dir = (@resdir + 'testdirectory')
		@obj.resource_directory?( dir.basename ).should be_false()
		dir.mkpath
		@obj.resource_directory?( dir.basename ).should be_true()
	end

end

# Workaround for RSpec's stupid overridden 'include' magic tricks
class AbstractTestClass < ::Object
	include ThingFish::AbstractClass
	virtual :test_method
end
class AbstractTestSubclass < AbstractTestClass
end

describe "ThingFish::AbstractClass mixed into a class" do
	it "will cause the including class to hide its ::new method" do
		lambda {
			AbstractTestClass.new
		}.should raise_error( NoMethodError, /private/ )
	end

end


describe "ThingFish::AbstractClass mixed into a superclass" do
	before(:each) do
		@instance = AbstractTestSubclass.new
	end


	it "raises a NotImplementedError when unimplemented API methods are called" do
		lambda {
			@instance.test_method
		}.should raise_error( NotImplementedError, /does not provide an implementation of/ )
	end

end


describe ThingFish::NumericConstantMethods, " after extending Numeric" do

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

	
	it "can display integers as human readable filesize values" do
		234.size_suffix.should == "234b"
		3492.size_suffix.should == "3.4K"
		3492425.size_suffix.should == "3.3M"
		9833492425.size_suffix.should == "9.2G"
	end

end

