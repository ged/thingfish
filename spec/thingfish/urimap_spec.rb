#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/helpers'

	require 'thingfish'
	require 'thingfish/config'
	require 'thingfish/constants'
	require 'thingfish/urimap'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::UriMap do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :debug )
	end

	before( :each ) do
		@urimap = ThingFish::UriMap.new
	end

	after( :all ) do
		reset_logging()
	end


	# Dispatcher notes:
	# 
	#  /: PermissionHandler
	#  /admin: AdminAccessHandler
	#  /admin/disk_usage: DiskUsageAdminHandler
	# 
	#  /admin/disk_usage/quota/username
	# 
	#  PermissionHandler:     admin/disk_usage/quota/username
	#  AdminAccessHandler:    disk_usage/quota/username
	#  DiskUsageAdminHandler: quota/username
	# 
	it "allows you to associate a handler with a uri" do
		handler = stub( "handler object" )
		@urimap.register( '/admin', handler )
		@urimap.handlers_for( '/admin' ).should have( 1 ).members
		@urimap.handlers_for( '/admin' ).should include( handler )
	end
	
	
	it "allows you to associate two handlers with a uri" do
		handler = stub( "handler object" )
		handler2 = stub( "second handler object" )
		@urimap.register( '/admin', handler )
		@urimap.register( '/admin', handler2 )
		@urimap.handlers_for( '/admin' ).should have( 2 ).members
		@urimap.handlers_for( '/admin' ).should == [ handler, handler2 ]
	end

	it "allows you to register a handler before any currently-registered ones for a given uri" do
		handler = stub( "handler object" )
		handler2 = stub( "second handler object" )
		@urimap.register( '/admin', handler )
		@urimap.register_first( '/admin', handler2 )
		@urimap.handlers_for( '/admin' ).should have( 2 ).members
		@urimap.handlers_for( '/admin' ).should == [ handler2, handler ]
	end

	it "handles multiple delegator handlers mapped to a single part of the urispace" do
		handler1 = stub( "a handler object" )
		handler2 = stub( "another handler object" )
		handler3 = stub( "another handler object" )
		
		@urimap.register( '/floppy', handler1 )
		@urimap.register( '/floppy', handler2 )
		@urimap.register( '/floppy/yes/they/are', handler3 )
		
		delegators, processor = @urimap[ '/floppy/yes/they/are/unfluffed' ]
		
		delegators.should == [ handler1, handler2 ]
		processor.should == handler3
	end


	it "handles a delegator and a processor mapped to the most-specific part of the urispace" do
		handler1 = stub( "a handler object" )
		handler2 = stub( "another handler object" )
		handler3 = stub( "another handler object" )
		
		@urimap.register( '/floppy', handler1 )
		@urimap.register( '/floppy/yes/they/are', handler2 )
		@urimap.register( '/floppy/yes/they/are', handler3 )
		
		delegators, processor = @urimap[ '/floppy/yes/they/are/unfluffed' ]
		
		delegators.should == [ handler1, handler2 ]
		processor.should == handler3
	end


	describe "with three registered handlers for a specific URI" do
		
		before( :each ) do
			@handler = stub( "handler object" )
			@urimap.register( '/admin', @handler )

			@handler2 = stub( "second handler object" )
			@urimap.register( '/', @handler2 )
		
			@handler3 = stub( "third handler object" )
			@urimap.register( '/admin/file_quota', @handler3 )
			
			@uri = URI.parse( "/admin/file_quota" )
		end
		
		it "knows what handlers are delegators for a given uri" do
			@urimap.delegators_for( @uri ).should == [ @handler2, @handler ]
		end

		it "knows what handler is the processor for a given uri" do
			@urimap.processor_for( @uri ).should == @handler3
		end

		it "maps a uri to an Array of delegator handlers and a processor handler that are " +
		   "responsible for handling it" do
		
			delegators, processor = @urimap[ @uri ]

			processor.should equal( @handler3 )
		
			delegators.should have( 2 ).members
			delegators.should == [ @handler2, @handler ]
		end
	end

end

# vim: set nosta noet ts=4 sw=4:
