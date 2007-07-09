#!/usr/bin/ruby
#
# Network-accessable searchable datastore
#
# == Synopsis
#
#
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
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

begin
    require 'rubygems'
rescue LoadError
end

require 'logger'
require 'uuidtools'


### Toplevel namespace module
module ThingFish

	require 'thingfish/constants'
	require 'thingfish/exceptions'
	require 'thingfish/mixins'

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Package version
	VERSION = '0.0.1'


	# Add some method to core classes
	Numeric.extend( ThingFish::NumericConstantMethods )

	# Global logging object
	@default_logger = Logger.new( $stderr )
	@default_logger.level = Logger::WARN
	@logger = @default_logger
	class << self
		attr_reader :default_logger
		attr_accessor :logger
	end


	### Reset the global logger object to the default
	def self::reset_logger
		self.logger = self.default_logger
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


### Add convenience methods to Numerics
class Numeric
	include ThingFish::NumericConstantMethods::Time,
	        ThingFish::NumericConstantMethods::Bytes
end


# Define an #== if none exists
class UUID

	### Only add an #== method if there's not already one defined
	unless instance_methods( false ).include?( "==" )
		
		### Return +true+ if the given +other_uuid+ is the same as the
		### receiver.
		def ==( other_uuid )
			other_uuid = self.class.parse( other_uuid.to_s ) unless
				other_uuid.is_a?( self.class )
			return (self <=> other_uuid).zero?
		rescue ArgumentError
			return false
		end
		alias_method :eql?, :==
	end
end


