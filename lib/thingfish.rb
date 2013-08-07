#!/usr/bin/env ruby

require 'loggability'
require 'configurability'

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
module ThingFish
	extend Loggability


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

end # module ThingFish

# vim: set nosta noet ts=4 sw=4:
