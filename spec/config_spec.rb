#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

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

	before(:each) do
		@config = ThingFish::Config.new
	end

	it "dumps itself as YAML" do
		@config.dump.should =~ /^ip:/
		@config.dump.should =~ /^port:/
	end

	it "responds to methods which are the same as struct members" do
		@config.respond_to?( :ip ).should == true
		@config.plugins.respond_to?( :handlers ).should == true
		@config.respond_to?( :pork_sausage ).should == false
	end
	
	it "returns nil as its change description" do
		@config.changed_reason.should == nil
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
			violated( "Config with no source shouldn't invoke the handlers block")
		end
	end
	
	it "raises an error on a handler config of a simple string" do
		Proc.new {
			@config.parse_handler_config( 'echo' )
		}.should raise_error( ThingFish::ConfigError)
	end

	it "is able to parse a handler specification of a name and uri" do
		@config.parse_handler_config( {'echo' => '/'} ).should == 
			[ 'echo', ['/'], {} ]
	end

	it "is able to parse a handler specification of a name and an array of uris" do
		@config.parse_handler_config( {'echo' => ['/', '/echo']} ).should == 
			[ 'echo', ['/', '/echo'], {} ]
	end

	it "is able to parse a handler specification of a name and an options hash" do
		options = {
			'uris' => '/echo',
			'reverse' => false,
		}
		@config.parse_handler_config( {'echo' => options} ).should == 
			[ 'echo', ['/echo'], options ]
	end

	it "parses an empty array of URIs for a handler spec with options hash and no 'uris' key" do
		options = {
			'reverse' => false,
		}
		lambda {
			@config.parse_handler_config( {'echo' => options} )
		}.should raise_error( ThingFish::ConfigError)
	end

	it "is able to build a configured FileStore object" do
		@config.create_configured_filestore.should be_a_kind_of( ThingFish::FileStore )
	end

	it "is able to build a configured MetaStore object" do
		@config.create_configured_metastore.should be_a_kind_of( ThingFish::MetaStore )
	end

end


# With no source
describe ThingFish::Config, " created with no source" do
	before(:each) do
		@config = ThingFish::Config.new
	end


	it "should have default values" do
		@config.ip.should == DEFAULT_BIND_IP
		@config.port.should == DEFAULT_PORT
		@config.plugins.keys.should include( :filestore)
	end
end

TEST_CONFIG =<<END
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
    handlers:
        - ldap-authz:
            uris: /
            server: ldap.laika.com
            binddn: cn=auth,dc=wvs
            aclbase: ou=thingfish,ou=appperms,dc=wvs
            in_front: true
        - stats: 
            uris: [/, /admin, /metadata]
        - dav: /mount
        - admin: [/admin, /superuser]
        - inspect: /admin/inspect
    filters:
        - json
        - xml

mergekey: Yep.
END

# Created with source
describe ThingFish::Config, " created with source" do
	before(:each) do
		@config = ThingFish::Config.new( TEST_CONFIG )
	end

	### Specifications
	it "should contain values specified in the source" do
		@config.ip.should == '127.0.0.1'
		@config.port.should == 3474
		@config.spooldir.should == '/vagrant/swahili'
		@config.bufsize.should == 2
		@config.plugins.keys.should include( :filestore)
		@config.plugins.keys.should include( :metadata)
		@config.plugins.keys.should include( :handlers)
		@config.plugins.keys.should include( :filters)
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

end


describe ThingFish::Config, " whose internal values have been changed since loaded" do
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


describe ThingFish::Config, " loaded from a file" do
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


describe ThingFish::Config, " whose file changes after loading" do
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


describe ThingFish::Config, " created by merging two other configs" do
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


BAD_TEST_CONFIG =<<END
---
port: 3474
ip: 127.0.0.1

logging:
    level: warn
    logfile: stderr

plugins:
    handlers:
        dav: /mount
        admin: [/admin, /superuser]
END

# Created with bad source
describe ThingFish::Config, " created with an illegal handlers section" do
	before(:each) do
	    @config = ThingFish::Config.new( BAD_TEST_CONFIG )
	end
	
	it "should raise an exception when iterating over handler uris" do
		lambda { @config.each_handler_uri {} }.should raise_error( ThingFish::ConfigError)
	end
end


NO_FILESTORE_PLUGIN_CONFIG =<<END
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
    handlers:
        - ldap-authz:
            uris: /
            server: ldap.laika.com
            binddn: cn=auth,dc=wvs
            aclbase: ou=thingfish,ou=appperms,dc=wvs
            in_front: true
        - stats: 
            uris: [/, /admin, /metadata]
        - dav: /mount
        - admin: [/admin, /superuser]
        - inspect: /admin/inspect
    filters:
        - json
        - xml
        - rubymarshal
END

# Created with bad source
describe ThingFish::Config, " created without a filestore plugin section" do
	before(:each) do
	    @config = ThingFish::Config.new( NO_FILESTORE_PLUGIN_CONFIG )
	end
	
	it "should get the default filestore section" do
		@config.plugins.filestore.should be_a_kind_of( ThingFish::Config::ConfigStruct)
	end
end


TEST_HANDLER_URI_CONFIG =<<END
---
plugins:
    handlers:
        - dav: /mount
        - admin: [/admin, /superuser]
        - inspect: /admin/inspect
END

describe ThingFish::Config, " with configured handlers" do

	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end

	after( :all ) do
		ThingFish.reset_logger
	end

	before(:each) do
	    @config = ThingFish::Config.new( TEST_HANDLER_URI_CONFIG )
	end


	it "can find the uri of installed handler plugins" do
		@config.find_handler_uri( 'dav' ).should == '/mount'
	end

	it "can find the first uri of handler plugins that are installed in more than one place" do
		@config.find_handler_uri( 'admin' ).should == '/admin'
	end

	it "returns nil if asked for the uri of a handler that isn't installed" do
		@config.find_handler_uri( 'moonlanding' ).should be_nil()
	end

end


# vim: set nosta noet ts=4 sw=4:
