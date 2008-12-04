#!/usr/bin/ruby
#
# Network-accessable searchable datastore
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.

#

begin
	require 'logger'
	require 'pluginfactory'
	require 'uuidtools'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end



### Toplevel namespace module
module ThingFish

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Package version
	VERSION = '0.2.1'

	# Need to require these here so some constants are already defined
	require 'thingfish/constants'
	require 'thingfish/mixins'
	require 'thingfish/utils'


	# Global logging object
	require 'thingfish/utils'


	@default_logger = Logger.new( $stderr )
	@default_logger.level = Logger::WARN

	@default_log_formatter = ThingFish::LogFormatter.new( @default_logger )
	@default_logger.formatter = @default_log_formatter

	@logger = @default_logger

	PluginFactory::logger_callback = lambda do |lvl, msg|
		@logger.debug "[%s] %s" % [ lvl.to_s, msg ]
	end

	class << self
		# The log formatter that will be used when the logging subsystem is reset
		attr_accessor :default_log_formatter

		# The logger that will be used when the logging subsystem is reset
		attr_accessor :default_logger

		# The logger that's currently in effect
		attr_accessor :logger
	end


	### Reset the global logger object to the default
	def self::reset_logger
		self.logger = self.default_logger
		self.logger.level = Logger::WARN
		self.logger.formatter = self.default_log_formatter
	end


	### Returns +true+ if the global logger has not been set to something other than
	### the default one.
	def self::using_default_logger?
		return self.logger == self.default_logger
	end


	### Return the server's version string
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %d)" % [ SVNRev[/\d+/].to_i ] if include_buildnum
		return vstring
	end
end # module ThingFish


### Load all overrides after everything else has a chance to load.
require 'monkeypatches'


# vim: set nosta noet ts=4 sw=4:
