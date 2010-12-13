#!/usr/bin/env ruby

require 'logger'
require 'pluginfactory'
require 'uuidtools'

#
# Network-accessable searchable datastore
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
module ThingFish

	# VCS Revision
	VCSRev = %q$Rev$

	# Package version
	VERSION = '0.3.0'

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

	@configured_html_mimetype = ThingFish::Constants::HTML_MIMETYPE


	class << self
		# The log formatter that will be used when the logging subsystem is reset
		attr_accessor :default_log_formatter

		# The logger that will be used when the logging subsystem is reset
		attr_accessor :default_logger

		# The logger that's currently in effect
		attr_accessor :logger

		# Set the mimetype given to HTML by default
		attr_accessor :configured_html_mimetype
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
		if include_buildnum
			build = VCSRev[ /: (\w+)/, 1 ] || 0
			vstring << " (build %s)" % [ build ]
		end
		return vstring
	end

end # module ThingFish


### Load all overrides after everything else has a chance to load.
require 'monkeypatches'


# vim: set nosta noet ts=4 sw=4:
