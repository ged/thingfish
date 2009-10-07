#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec'
	require 'logger'
	require 'thingfish'
	require 'spec/lib/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::TestConstants


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish do

	it "should know if its default logger is replaced" do
		ThingFish.reset_logger
		ThingFish.should be_using_default_logger
		ThingFish.logger = Logger.new( $stderr )
		ThingFish.should_not be_using_default_logger
	end


	it "returns a version string if asked" do
		ThingFish.version_string.should =~ /\w+ [\d.]+/
	end


	it "returns a version string with a build number if asked" do
		ThingFish.version_string(true).should =~ /\w+ [\d.]+ \(build \d+\)/
	end


	describe " logging subsystem" do
		before(:each) do
			ThingFish.reset_logger
		end

		after(:each) do
			ThingFish.reset_logger
		end


		it "has the default logger instance after being reset" do
			ThingFish.logger.should equal( ThingFish.default_logger )
		end

		it "has the default log formatter instance after being reset" do
			ThingFish.logger.formatter.should equal( ThingFish.default_log_formatter )
		end

	end


	describe " logging subsystem with new defaults" do
		before( :all ) do
			@original_logger = ThingFish.default_logger
			@original_log_formatter = ThingFish.default_log_formatter
		end

		after( :all ) do
			ThingFish.default_logger = @original_logger
			ThingFish.default_log_formatter = @original_log_formatter
		end


		it "uses the new defaults when the logging subsystem is reset" do
			logger = mock( "dummy logger", :null_object => true )
			formatter = mock( "dummy logger" )

			ThingFish.default_logger = logger
			ThingFish.default_log_formatter = formatter

			logger.should_receive( :formatter= ).with( formatter )

			ThingFish.reset_logger
			ThingFish.logger.should equal( logger )
		end


	end

end


# vim: set nosta noet ts=4 sw=4 ft=rspec:
