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
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#
# == Copyright
#
# Any and all patches included here are hereby given back to the author/s of the
# respective original projects without limitation.
#
#
#

require 'rubygems'

require 'uuidtools'
require 'thingfish/mixins'

### Add HTML output to the core Object
class Object
	include ThingFish::HtmlInspectableObject
end

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

	### A more-efficient version of UUIDTools' UUID parser -- see
	### experiments/bench-uuid-parse.rb in the subversion source.
	def parse( uuid_string )
		unless match = UUID_PATTERN.match( uuid_string )
			raise ArgumentError, "Invalid UUID %p." % [uuid_string]
		end

		uuid_components = match.captures

		time_low = uuid_components[0].to_i( 16 )
		time_mid = uuid_components[1].to_i( 16 )
		time_hi_and_version = uuid_components[2].to_i( 16 )
		clock_seq_hi_and_reserved = uuid_components[3].to_i( 16 )
		clock_seq_low = uuid_components[4].to_i( 16 )

		nodes = []
		0.step( 11, 2 ) do |i|
			nodes << uuid_components[5][ i, 2 ].to_i( 16 )
		end

		return UUID.new( time_low, time_mid, time_hi_and_version,
		                 clock_seq_hi_and_reserved, clock_seq_low, nodes )
	end
end
