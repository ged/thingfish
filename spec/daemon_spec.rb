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


include ThingFish::TestConstants

class TestHandler < ThingFish::Handler
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe "The daemon class" do

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

describe "A new root-started daemon with a user configged" do

	before(:each) do
		@config = ThingFish::Config.new
		@config.user = 'not-root'
		@daemon = ThingFish::Daemon.new( @config )
	end


	it "drops privileges" do
		Process.should_receive(:euid).at_least(:once).and_return(0)
	
		pwent = mock( 'not-root pw entry' ) 
		Etc.should_receive( :getpwnam ).with( @config.user ).and_return( pwent )
		pwent.should_receive( :uid ).and_return( 1000 )

		Process.should_receive( :euid= ).with( 1000 )
		@daemon.run
	end
end


describe "A new daemon with a differing port config" do

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
