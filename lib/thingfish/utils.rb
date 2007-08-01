#!/usr/bin/ruby
#
# A collection of little utility classes used elsewhere throughout the code
#
# == Synopsis
#
#   require 'thingfish/utils'
#
#   # Table (case-insensitive hash)
#   headers = ThingFish::Table.new
#   headers['User-Agent'] = 'PornBrowser 1.1.5'
#   headers['user-agent']  # => 'PornBrowser 1.1.5'
#   headers[:user_agent]   # => 'PornBrowser 1.1.5'
#
# == Description
#
# This module includes a collection of little utility classes:
#
# === ThingFish::Table
#
# A case-insensitive multivalue hash that allows access via Symbol or String.
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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish'


module ThingFish # :nodoc:

	### A case-insensitive multivalue hash that allows access via Symbol or String.
	class Table
		
		### Create a new ThingFish::Table using the given +hash+ for initial
		### values.
		def initialize( initial_values={} )
			@hash = {}
			initial_values.each {|k,v| self.append(k, v) }
		end
		
		
		######
		public
		######

		### Index assignment operator
		def []=( key, value )
			@hash[ normalize_key(key) ] = value
		end
		
		
		### Index fetch operator
		def []( key )
			return @hash[ normalize_key(key) ]
		end


		### Append the given +key+/+value+ pair to the table, transforming
		### it into an array if there was an existing value for the same
		### key. 
		def append( key, value )
			nkey = normalize_key( key )
			if @hash.key?( nkey )
				@hash[ nkey ] = [ @hash[nkey] ] unless
					@hash[nkey].is_a?( Array )
				@hash[ nkey ] << value
			else
				@hash[ nkey ] = value
			end
		end
		
		
		
		#######
		private
		#######

		### Normalize the given key to equivalence
		def normalize_key( key )
			key.to_s.downcase.gsub('-', '_').to_sym
		end
		
		
	end # class Table

	

end # module ThingFish

# vim: set nosta noet ts=4 sw=4:

