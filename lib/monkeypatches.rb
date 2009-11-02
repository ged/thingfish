#!/usr/bin/ruby
#
# This file
# includes various necessary modifications to libraries we depend on. It pains us to
# do it, but sometimes you just gotta patch the monkey.
#
# == Version
#
#  $Id$
#
# == Authors
# This file includes code written by other people
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# == Copyright
#
# Any and all patches included here are hereby given back to the author/s of the
# respective original projects without limitation.
#
#
#

require 'thingfish/mixins'
require 'thingfish/constants'


### Add HTML output to the core Object
class Object
	include ThingFish::HtmlInspectableObject
end

### Add convenience methods to Numerics
class Numeric
	include ThingFish::NumericConstantMethods::Time,
	        ThingFish::NumericConstantMethods::Bytes
end


