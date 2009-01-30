#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'tempfile'
	require 'logger'
	require 'fileutils'

	require 'spec/runner'
	require 'spec/lib/helpers'

	require 'thingfish'
	require 'thingfish/config'
	require 'thingfish/constants'
	require 'thingfish/filestore'
	require 'thingfish/metastore'
	require 'thingfish/handler'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants


#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::Config do
	include ThingFish::SpecHelpers

	before( :all ) do
		setup_logging( :fatal )
	end

	before(:each) do
		@config = ThingFish::Config.new
	end

	after( :all ) do
		reset_logging()
	end


	it "dumps itself as YAML" do
		@config.dump.should =~ /^ip:/
		@config.dump.should =~ /^port:/
	end

	it "responds to methods which are the same as struct members" do
		@config.respond_to?( :ip ).should == true
		@config.plugins.respond_to?( :urimap ).should == true
		@config.respond_to?( :pork_sausage ).should == false
	end


	it "returns nil as its change description" do
		@config.changed_reason.should == nil
	end


	it "can qualify paths relative to the configured datadir" do
		@config.datadir = '/glah'
		@config.qualify_path( 'woot' ).should == Pathname.new( '/glah/woot' )
	end


	it "constructs the spool directory path relative to the data directory if it isn't absolute" do
		@config.datadir = '/tmp'
		@config.spooldir = 'spool'
		@config.spooldir_path.should == Pathname.new( '/tmp/spool' )
	end


	it "constructs the profile directory path relative to the data directory if it isn't absolute" do
		@config.datadir = '/tmp'
		@config.profiling.profile_dir = 'profiles'
		@config.profiledir_path.should == Pathname.new( '/tmp/profiles' )
	end


	it "ensures the data and spool directories exist" do
		datadir_pathname = mock( "mock datadir pathname" )
		@config.datadir = :datadir
		Pathname.should_receive( :new ).with( :datadir ).at_least(:once).
			and_return( datadir_pathname )

		spooldir_pathname = mock( "mock spooldir pathname" )
		@config.spooldir = :spooldir
		Pathname.should_receive( :new ).with( :spooldir ).and_return( spooldir_pathname )

		datadir_pathname.should_receive( :mkpath )
		spooldir_pathname.should_receive( :relative? ).and_return( false )
		spooldir_pathname.should_receive( :mkpath )

		@config.setup_data_directories
	end


	it "doesn't replace an installed logger if it's not the default logger" do
		logger = Logger.new( $stderr )
		ThingFish.logger = logger
		ThingFish.logger.level = Logger::WARN
		@config.install
		ThingFish.logger.should equal( logger )
	end

	it "parses a log level of 'debug' as Logger::DEBUG" do
		@config.logging.level = 'debug'
		@config.parsed_logging_level.should == Logger::DEBUG
	end

	it "parses a log level of 'info' as Logger::INFO" do
		@config.logging.level = 'info'
		@config.parsed_logging_level.should == Logger::INFO
	end

	it "parses a log level of 'warn' as Logger::WARN" do
		@config.logging.level = 'warn'
		@config.parsed_logging_level.should == Logger::WARN
	end

	it "parses a log level of 'error' as Logger::ERROR" do
		@config.logging.level = 'error'
		@config.parsed_logging_level.should == Logger::ERROR
	end

	it "parses a log level of 'fatal' as Logger::FATAL" do
		@config.logging.level = 'fatal'
		@config.parsed_logging_level.should == Logger::FATAL
	end

	it "raises an exception if the specified log level cannot be parsed" do
		@config.logging.level = 'clowncar'
		@config.method(:parsed_logging_level).to_proc.should raise_error( ArgumentError )
	end

	it "parses a logfile of 'stderr' to the STDERR IO object" do
		@config.logging.logfile = 'stderr'
		@config.parsed_logfile.should == $stderr
	end

	it "parses a logfile of 'DEFOUT' to the STDOUT IO object" do
		@config.logging.logfile = 'DEFOUT'
		@config.parsed_logfile.should == $stdout
	end

	it "parses a logfile of 'STDERR' to the STDERR IO object" do
		@config.logging.logfile = 'STDERR'
		@config.parsed_logfile.should == $stderr
	end

	it "parses a logfile of 'stdout' to the STDOUT IO object" do
		@config.logging.logfile = 'stdout'
		@config.parsed_logfile.should == $stdout
	end

	it "parses an unspecified logfile as nil" do
		@config.logging.logfile = nil
		@config.parsed_logfile.should == nil
	end

	LOGPATH = '/tmp/logfile'
	it "returns a parsed path as-is" do
		@config.logging.logfile = LOGPATH
		@config.parsed_logfile.should == LOGPATH
	end

	it "raises an error on a relative logfile path" do
		@config.logging.logfile = 'foo/bar'
		lambda {
			@config.parsed_logfile
		}.should raise_error( ThingFish::ConfigError, /absolute path/ )
	end

	it "returns struct members as an Array of Symbols" do
		@config.members.should be_an_instance_of( Array )
		@config.members.should have_at_least( 4 ).things
		@config.members.each do |member|
			member.should be_an_instance_of( Symbol)
		end
	end

	it "is able to iterate over sections" do
		@config.each do |key, struct|
			key.should be_an_instance_of( Symbol)
		end
	end

	it "is able to iterate over each configured handler" do
		lambda { @config.each_handler_uri }.should raise_error( LocalJumpError)
		@config.each_handler_uri do |*args|
			nonexistent_method( "Config with no source shouldn't invoke the handlers block" )
		end
	end

	it "is able to build a configured FileStore object" do
		default_filestore = ThingFish::Config::DEFAULTS[:plugins][:filestore][:name]
		ThingFish::FileStore.should_receive( :create ).
			with( default_filestore, an_instance_of(Pathname), an_instance_of(Pathname), {} ).
			and_return( :a_filestore )
		@config.create_configured_filestore.should == :a_filestore
	end

	it "is able to build a configured MetaStore object" do
		default_metastore = ThingFish::Config::DEFAULTS[:plugins][:metastore][:name]
		ThingFish::MetaStore.should_receive( :create ).
			with( default_metastore, an_instance_of(Pathname), an_instance_of(Pathname), {} ).
			and_return( :a_metastore )
		@config.create_configured_metastore.should == :a_metastore
	end

	it "outputs a new instance's handler config to the debug log" do
		log = StringIO.new('')
		ThingFish.logger = Logger.new( log )

		@config.create_configured_urimap
		
		log.rewind
		log.read.should =~ %r{URI map is: \S+}
	end
	
	it "autogenerates accessors for non-existant struct members" do
		@config.plugins.filestore.maxsize = 1024
		@config.plugins.filestore.maxsize.should == 1024
	end


	# With no source
	describe " created with no source" do
		before(:each) do
			@config = ThingFish::Config.new
		end

		it "should have default values" do
			@config.ip.should == DEFAULT_BIND_IP
			@config.port.should == DEFAULT_PORT
			@config.plugins.keys.should include( :filestore)
		end

	end


	# Created with source
	describe " created with source" do
		TEST_CONFIG = %{
		---
		port: 3474
		ip: 127.0.0.1
		spooldir: /vagrant/swahili
		bufsize: 2

		logging:
		    level: warn
		    logfile: stderr

		plugins:
		    filestore:
		        name: /filestore/posix_fs
		        root: /var/db/thingfish
		        hashdepth: 4
		    metadata:
		        name: berkeleydb
		        root: /var/db/thingfish
		        extractors:
		            - exif
		            - preview
		    filters:
		        - json
		        - xml
		        - something:
		              key: value

		mergekey: Yep.
		}.gsub(/^\t\t/, '')


		before(:each) do
			@config = ThingFish::Config.new( TEST_CONFIG )
		end

		### Specifications
		it "should contain values specified in the source" do
			@config.ip.should == '127.0.0.1'
			@config.port.should == 3474
			@config.spooldir.should == '/vagrant/swahili'
			@config.bufsize.should == 2
			@config.plugins.keys.should include( :filestore )
			@config.plugins.keys.should include( :metadata )
			@config.plugins.keys.should include( :urimap )
			@config.plugins.keys.should include( :filters )
			@config.plugins.filestore.hashdepth.should == 4
			@config.plugins.metadata.extractors.should be_an_instance_of( Array )
		end

		it "should dump values specified in the source" do
			@config.dump.should =~ /^ip:/
			@config.dump.should =~ /^port:/
			@config.dump.should =~ /^plugins:/
			@config.dump.should =~ /^\s+filestore:/
			@config.dump.should =~ %r{^\s+- exif}
		end


		it "should know configured filter order" do

			ThingFish::Filter.should_receive( :create ).
				exactly(3).times.
				and_return {|name, opts| name.to_sym }

			filters = @config.create_configured_filters

			filters.should == [:json, :xml, :something]
		end
	end


	# saving if changed since loaded
	describe " whose internal values have been changed since loaded" do
		before(:each) do
			@config = ThingFish::Config.new( TEST_CONFIG )
			@config.port = 11451
		end


		### Specifications
		it "should report that it is changed" do
			@config.changed?.should == true
		end

		it "should report that its internal struct was modified as the reason for the change" do
			@config.changed_reason.should =~ /struct was modified/i
		end

	end


	# loading from a file
	describe " loaded from a file" do
		before(:all) do
			@tmpfile = Tempfile.new( 'test.conf', '.' )
			@tmpfile.print( TEST_CONFIG )
			@tmpfile.close
		end

		after(:all) do
			@tmpfile.delete
		end


		before(:each) do
			@config = ThingFish::Config.load( @tmpfile.path )
		end


		### Specifications
		it "should know which file it was loaded from" do
			@config.name.should == File.expand_path( @tmpfile.path )
		end

		it "should write itself back to the same file by default" do
			@config.port = 114411
			@config.write
			otherconfig = ThingFish::Config.load( @tmpfile.path )

			otherconfig.port.should == 114411
		end
	end


	# reload if file changes
	describe " whose file changes after loading" do
		before(:all) do
			@tmpfile = Tempfile.new( 'test.conf', '.' )
			@tmpfile.print( TEST_CONFIG )
			@tmpfile.close
		end

		after(:all) do
			@tmpfile.delete
		end


		before(:each) do
			@config = ThingFish::Config.load( @tmpfile.path )
			newdate = Time.now + 3600
			File.utime( newdate, newdate, @tmpfile.path )
		end


		### Specifications
		it "should report that it is changed" do
			@config.should be_changed
		end

		it "should report that its source was updated as the reason for the change" do
			@config.changed_reason.should =~ /source.*updated/i
		end

		it "should be able to be reloaded" do
			@config.reload
		end

	end


	# merging
	describe " created by merging two other configs" do
		before(:each) do
			@config1 = ThingFish::Config.new
			@config2 = ThingFish::Config.new( TEST_CONFIG )
			@merged = @config1.merge( @config2 )
		end


		### Specifications
		it "should contain values from both" do
			@merged.mergekey.should == @config2.mergekey
		end
	end


	# illegal urimap section
	describe " created with an illegal urimap section" do
		BAD_TEST_CONFIG = %{
		---
		port: 3474
		ip: 127.0.0.1

		logging:
		    level: warn
		    logfile: stderr

		plugins:
		    urimap:
		        dav: 
		            - mount: mount
		        /admin:
		            - admin: adminaccess
		}.gsub( /^\t\t/, '' )


		before(:each) do
		    @config = ThingFish::Config.new( BAD_TEST_CONFIG )
		end

		it "should raise an exception when iterating over handler uris" do
			ThingFish::Handler.stub!( :create ).and_return( :a_handler )
			lambda {
				@config.each_handler_uri {}
			}.should raise_error( ThingFish::ConfigError, /key \S+ is not a path/i )
		end
	end


	# without filestore plugin section
	describe " created without a filestore plugin section" do
		NO_FILESTORE_PLUGIN_CONFIG = %{
		---
		port: 3474
		ip: 127.0.0.1
		spooldir: /tmp
		bufsize: 65535

		logging:
		    level: warn
		    logfile: stderr

		plugins:
		    metastore:
		        name: pudding
		        root: /var/db/thingfish
		        extractors:
		            - exif
		            - preview
		    filters:
		        - json
		        - xml
		        - rubymarshal
		        - something:
		              key: value

		}.gsub( /^\t\t/, '' )

		before(:each) do
		    @config = ThingFish::Config.new( NO_FILESTORE_PLUGIN_CONFIG )
		end

		it "should get the default filestore section" do
			@config.plugins.filestore.should be_a_kind_of( ThingFish::Config::ConfigStruct)
		end
	end


	# configured handlers
	describe " with configured handlers" do

		before( :all ) do
			setup_logging( :fatal )
		end

		after( :all ) do
			reset_logging()
		end

		TEST_HANDLER_URI_CONFIG = %{
		---
		plugins:
		    urimap:
		        /: erblughuhuhuh
		        /mount: dav
		        /admin: admin
		        /admin/inspect:
		            - inspect: ~
		        /chunky/macHocksalot/:
		            - throatspasm:
		                gag: yes
		                hock: yeah
		                spit: never
		}.gsub( /^\t\t/, '' )

		before(:each) do
		    @config = ThingFish::Config.new( TEST_HANDLER_URI_CONFIG )
		end


		it "raises an exception if the handler map hasn't been populated when asked for a " +
		   "handler's uri" do
			ThingFish::Handler.stub!( :create ).and_return( :the_handler )
			lambda {
				@config.find_handler_uri( 'dav' )
			}.should raise_error( RuntimeError, /isn't populated yet/i )
		end
		
		
		it "yields tuples for handlers that should be mapped into the urispace" do
			ThingFish::Handler.should_receive( :create ).with( 'erblughuhuhuh', '', {} ).
				and_return( :slashhandler )
			ThingFish::Handler.should_receive( :create ).with( 'dav', '/mount', {} ).
				and_return( :davhandler )
			ThingFish::Handler.should_receive( :create ).with( 'admin', '/admin', {} ).
				and_return( :adminhandler )
			ThingFish::Handler.should_receive( :create ).with( 'inspect', '/admin/inspect', nil ).
				and_return( :inspecthandler )
			ThingFish::Handler.should_receive( :create ).
				with( 'throatspasm', '/chunky/macHocksalot', an_instance_of(Hash) ).
				and_return( :hungryhandler )
			
			results = []
			@config.each_handler_uri do |handler, path|
				results << [ handler, path ]
			end

			# Gulpy McGrunterson
			# Cleary Mustacheerton McThroaterson
			# Swallowy McMucus
			results.should have(5).members
			results.should include(
				[ :slashhandler, '' ],
				[ :davhandler, '/mount' ],
				[ :adminhandler, '/admin' ],
				[ :inspecthandler, '/admin/inspect' ],
				[ :hungryhandler, '/chunky/macHocksalot' ]
			)
		end
		
		it "is able to build a configured URImap object" do
			urimap = mock( "the urimap" )
			ThingFish::UriMap.stub!( :new ).and_return( urimap )

			ThingFish::Handler.stub!( :create ).and_return( :a_handler )
			urimap.should_receive( :register ).at_least( 6 ).times

			@config.create_configured_urimap.should == urimap
		end

		it "can find the uri of installed handler plugins" do
			ThingFish::Handler.stub!( :create ).and_return( :the_handler )
			@config.each_handler_uri {}
			@config.find_handler_uri( 'dav' ).should == '/mount'
		end

		it "can find the first uri of handler plugins that are installed in more than one place" do
			ThingFish::Handler.stub!( :create ).and_return( :the_handler )
			@config.each_handler_uri {}
			@config.find_handler_uri( 'admin' ).should == '/admin'
		end

		it "returns nil if asked for the uri of a handler that isn't installed" do
			ThingFish::Handler.stub!( :create ).and_return( :the_handler )
			@config.each_handler_uri {}
			@config.find_handler_uri( 'moonlanding' ).should be_nil()
		end

	end


	describe " with profiling enabled" do

		TEST_PROFILING_ENABLED_CONFIG = %{
		---
		profiling:
		  enabled: true
		  profile_dir: profiles
		}.gsub( /^\t\t/, '' )

		before(:each) do
		    @config = ThingFish::Config.new( TEST_PROFILING_ENABLED_CONFIG )
		end


		it "ensures the profiling report directory exists" do
			datadir_pathname = stub( "mock datadir pathname", :mkpath => false )
			@config.datadir = :datadir
			Pathname.should_receive( :new ).with( :datadir ).at_least(:once).
				and_return( datadir_pathname )

			spooldir_pathname = stub( "mock spooldir pathname", :mkpath => false )
			@config.spooldir = :spooldir
			Pathname.should_receive( :new ).with( :spooldir ).and_return( spooldir_pathname )
			spooldir_pathname.stub!( :relative? ).and_return( false )

			profiledir_pathname = mock( "profiledir pathname" )
			Pathname.should_receive( :new ).with( 'profiles' ).and_return( profiledir_pathname )

			profiledir_pathname.should_receive( :relative? ).and_return( false )
			profiledir_pathname.should_receive( :mkpath )

			@config.setup_data_directories
		end

	end


	describe " with strict HTML enabled" do

		STRICT_HTML_ENABLED_CONFIG = %{
		---
		use_strict_html_mimetype: true
		}.gsub( /^\t\t/, '' )

		before(:each) do
		    @config = ThingFish::Config.new( STRICT_HTML_ENABLED_CONFIG )
		end


		it "redefines the CONFIGURED_HTML_MIMETYPE constant" do
			ThingFish::Constants.should_receive( :const_set ).
				with( :CONFIGURED_HTML_MIMETYPE, XHTML_MIMETYPE )
			@config.install
		end
	end

end

# vim: set nosta noet ts=4 sw=4:
