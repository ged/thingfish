#!/usr/bin/ruby
#
# A metastore that uses simple key/value pairs for ThingFish
#
# == Synopsis
#
#   require 'thingfish/metastore/simple'
#
#   class MyMetaStore < ThingFish::SimpleMetaStore
#       # ...
#   end
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
# Please see the file LICENSE in the top-level directory for licensing details.

#

require 'thingfish'
require 'thingfish/metastore'

### Base class for ThingFish MetaStore plugins
class ThingFish::SimpleMetaStore < ThingFish::MetaStore

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

end # class ThingFish::SimpleMetaStore


# vim: set nosta noet ts=4 sw=4:

