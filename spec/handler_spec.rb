#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/constants'
	require 'thingfish'
	require 'thingfish/handler'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants

class TestHandler < ThingFish::Handler
	public :log_request
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe "The base handler class" do
	it "should register subclasses as plugins" do
		ThingFish::Handler.get_subclass( 'test' ).should == TestHandler
	end
end


describe "An instance of a derivative class" do

	before(:each) do
	    @handler = ThingFish::Handler.create( 'test' )
		@datadir = Config::CONFIG['datadir']
	end


	### Specs
	it "knows what its normalized name is" do
		@handler.plugin_name.should == 'testhandler'
	end

	it "is able to output a consistent request log message" do
		logfile = StringIO.new('')
		ThingFish.logger = Logger.new( logfile )

		params = {
			'REQUEST_METHOD' => 'POST',
			'REMOTE_ADDR'    => '127.0.0.1',
			'REQUEST_URI'    => '/poon',
		}
		
		request = mock( "request object" )
		request.should_receive( :params ).at_least(1).and_return( params )
		
		@handler.log_request( request )
		logfile.rewind
		logfile.read.should =~ %r{\S+: 127.0.0.1 POST /poon}
	end
	
	it "gets references to the metastore and filestore from the listener callback" do
		mock_listener = mock( "listener", :null_object => true )
		mock_listener.should_receive( :filestore ).and_return( :filestore_obj )
		mock_listener.should_receive( :metastore ).and_return( :metastore_obj )
		
		@handler.listener = mock_listener
	end
	
end

# vim: set nosta noet ts=4 sw=4:
