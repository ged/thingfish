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
	require 'thingfish/daemon'
	require 'thingfish/config'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



class TestHandler < ThingFish::Handler
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe "The daemon class" do
	include ThingFish::TestConstants

	before(:each) do
		@log = StringIO.new('')
		ThingFish.logger = Logger.new( @log )
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )
	end

	it "outputs a new instance's handler config to the debug log" do
		@daemon = ThingFish::Daemon.new
		@log.rewind
		@log.read.should =~ %r{Handler map is:\s*/: \[.*?\]}
		# rescue Errno::EADDRINUSE
		# 	$stderr.puts "Skipping: something already running on the default port"
		# end
	end
end

describe "A new daemon with no arguments" do
	include ThingFish::TestConstants

	before(:each) do
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )
		@daemon = ThingFish::Daemon.new
	end

	it "uses default config IP" do
		@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
	end

	it "uses default config port" do
		@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port])
	end
end


describe "A new daemon with a differing ip config" do
	include ThingFish::TestConstants

	before(:each) do
		@config = ThingFish::Config.new
		@config.ip = TEST_IP

		# Gracefully handle the case where the testing host is already running 
		# something on the default port
		begin
			@daemon = ThingFish::Daemon.new( @config )
		rescue Errno::EADDRINUSE
			@daemon = nil
		end
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close if @daemon
	end


	it "binds to the test ip" do
		@daemon.host.should equal( TEST_IP) if @daemon
	end

	it "uses default config port" do
		@daemon.port.should equal( ThingFish::Config::DEFAULTS[:port]) if @daemon
	end
end


describe "A new daemon with a differing port config" do
	include ThingFish::TestConstants

	before(:each) do
		@config = ThingFish::Config.new
		@config.port = TEST_PORT
		@daemon = ThingFish::Daemon.new( @config )
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close
	end


	it "uses default config IP" do
		@daemon.host.should equal( ThingFish::Config::DEFAULTS[:ip])
	end

	it "binds to the test port" do
		@daemon.port.should equal( TEST_PORT)
	end
end


describe "A new daemon with an ip and host configured" do
	include ThingFish::TestConstants

	before(:each) do
		@config = ThingFish::Config.new
		@config.ip = TEST_IP
		@config.port = TEST_PORT
		@daemon = ThingFish::Daemon.new( @config )
	end

	after(:each) do
		# workaround EADDRINUSE
		@daemon.instance_variable_get( :@socket ).close
	end


	it "binds to the test ip" do
		@daemon.host.should equal( TEST_IP)
	end

	it "binds to test port" do
		@daemon.port.should equal( TEST_PORT)
	end

end


describe "A daemon with one or more handlers in its configuration" do
	include ThingFish::TestConstants

	before(:each) do
		@config = ThingFish::Config.new
		@config.plugins.handlers = [
			{'test' => '/test' },
		]
		
		@stub_socket = stub( "Server listener socket" )
		TCPServer.stub!( :new ).and_return( @stub_socket )
		@daemon = ThingFish::Daemon.new( @config )
	end

	it "registers its configured handlers" do
		@daemon.classifier.uris.length.should == 2
	end
	
end

describe "A running server" do
	include ThingFish::TestConstants

	before(:each) do
		@config = ThingFish::Config.new
		@config.port = 7777
		@daemon = ThingFish::Daemon.new( @config )
		@acceptor = @daemon.run
	end

	it "stops executing when shut down" do
		@daemon.shutdown
		@acceptor.should_not be_alive
	end
end


# vim: set nosta noet ts=4 sw=4:
