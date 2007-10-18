#!/usr/bin/ruby
# 
# ThingFish::MemoryMetaStore
# 
# == Synopsis
# 
#   require 'thingfish/metastore'
# 
#   metastore = ThingFish::MetaStore.create( 'memory' )
#   metadata = metastore[ uuid ]
#
#   metadata.key = value
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

require 'thingfish/metastore'
require 'thingfish/constants'
require 'thingfish/mixins'

### In-memory metadata store
class ThingFish::MemoryMetaStore < ThingFish::MetaStore
	include ThingFish::Loggable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new MemoryMetaStore with the specified +options+.
	def initialize( options={} )
		@options = options
		@metadata = Hash.new {|hash,key| hash[key] = {} }
		super
	end
	


	### Mandatory MetaStore API
	
	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		@metadata[ uuid.to_s ][ propname.to_sym ] = value
	end

	
	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		return @metadata[ uuid.to_s ][ propname.to_sym ]
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		return @metadata[ uuid.to_s ].clone
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		return @metadata[ uuid.to_s ].key?( propname.to_sym )
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		return @metadata[ uuid.to_s ].delete( propname.to_sym ) ? true : false
	end
	
	
	### MetaStore API: Removes all properties from given +uuid+
	def delete_properties( uuid )
		count = @metadata[ uuid.to_s ].length
		@metadata.delete( uuid.to_s )
		return count
	end


	### MetaStore API: Return all property keys in store
	def get_all_property_keys
		return @metadata.collect do | uuid, props |
			props.keys
		end.flatten.uniq
	end


	### MetaStore API: Return an array of uuids whose metadata matched the criteria
	### specified by +hash+. The criteria should be key-value pairs which describe
	### exact metadata pairs.
	def find_by_exact_properties( hash )
		uuids = hash.inject(nil) do |ary, pair|
			key, value = *pair
			key = key.to_sym

			matching_uuids = @metadata.keys.find_all do |uuid|
				@metadata[ uuid ][ key ] == value
			end
			
			if ary
				ary &= matching_uuids
			else
				ary = matching_uuids
			end
			
			ary
		end
		
		return uuids ? uuids : []
	end

end # class ThingFish::MemoryMetaStore

# vim: set nosta noet ts=4 sw=4:

