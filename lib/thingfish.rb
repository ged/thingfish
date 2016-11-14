#!/usr/bin/env ruby

require 'loggability'

# Network-accessable datastore service
module Thingfish
	extend Loggability


	# Loggability API -- log all Thingfish-related stuff to a separate logger
	log_as :thingfish


	# Package version
	VERSION = '0.5.0'

	# Version control revision
	REVISION = %q$Revision$


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


end # module Thingfish

# vim: set nosta noet ts=4 sw=4:
