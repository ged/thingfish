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
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
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
class ThingFish::SimpleMetaStore < ThingFish::MetaStore ; end

# vim: set nosta noet ts=4 sw=4:

