#!/usr/bin/env ruby

require 'thingfish/metastore/simple'
require 'thingfish/constants'
require 'thingfish/mixins'

#
# ThingFish::MemoryMetaStore - an in-memory metastore (not persistent)
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
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::MemoryMetaStore < ThingFish::SimpleMetaStore
	include ThingFish::Loggable


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new MemoryMetaStore with the specified +options+.
	def initialize( ignored_datadir=nil, ignored_spooldir=nil, options={} )
		@options = options
		@metadata = Hash.new {|hash,key| hash[key] = {} }
		super
	end


	###
	### Mandatory MetaStore API
	###

	### MetaStore API: Clear all resources from the store.
	def clear
		@metadata.clear
	end


	### MetaStore API: Returns +true+ if the given +uuid+ exists in the store.
	def has_uuid?( uuid )
		return @metadata.key?( uuid.to_s )
	end


	### MetaStore API: Set the property associated with +uuid+ specified by
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		@metadata[ uuid.to_s ][ propname.to_sym ] = value
	end


	### MetaStore API: Set the properties associated with the given +uuid+ to those
	### in the provided +propshash+.
	def set_properties( uuid, propshash )
		props = propshash.dup
		props.keys.each {|key| props[key.to_sym] = props.delete(key) unless key.is_a?(Symbol) }
		@metadata[ uuid.to_s ] = props
	end


	### MetaStore API: Merge the specified +propshash+ into the properties associated with the
	### given +uuid+.
	def update_properties( uuid, propshash )
		props = propshash.dup
		props.keys.each {|key| props[key.to_sym] = props.delete(key) unless key.is_a?(Symbol) }
		@metadata[ uuid.to_s ] = @metadata[ uuid.to_s ].merge( props )
	end


	### MetaStore API: Return the property associated with +uuid+ specified by
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		return @metadata[ uuid.to_s ][ propname.to_sym ]
	end


	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hash keyed by property names as symbols.
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


	### MetaStore API: Removes the values for the specified +keys+ from the metadata associated
	### with the given +uuid+.
	def delete_properties( uuid, *keys )
		rval = []

		keys.each do |key|
			rval << @metadata[ uuid.to_s ].delete( key.to_sym )
		end

		return rval
	end


	### MetaStore API: Removes all metadata for the given +uuid+.
	def delete_resource( uuid )
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


	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		key = key.to_sym
		return @metadata.collect do |uuid, props|
			props[ key ]
		end.compact.uniq
	end


	### MetaStore API: Return a hash keyed on uuid whose metadata values matched
	### the criteria specified by +key+ and +value+. This is an exact match search.
	def find_exact_uuids( key, value )
		key = key.to_sym

		matching_pairs = @metadata.find_all do |uuid, props|
			props[ key ].to_s.downcase == value.downcase
		end

		return Hash[ *(matching_pairs.flatten) ]
	end


	### MetaStore API: Return a hash keyed on uuid whose metadata values matched
	### the criteria specified by +key+ and +value+. This is a wildcard search.
	def find_matching_uuids( key, value )
		key = key.to_sym
		re = self.glob_to_regexp( value )

		matching_pairs = @metadata.find_all do |uuid, props|
			re.match( props[ key ].to_s )
		end

		return Hash[ *(matching_pairs.flatten) ]
	end


	### MetaStore API: Return all values in the store as a Hash keyed by UUID.
	def dump_store
		@metadata.dup
	end


	### Metastore API: Replace all values in the store with those in the given hash.
	def load_store( hash )
		@metadata.replace( hash.dup )
	end


	### Metastore API: Yield all the metadata in the store one resource at a time
	def each_resource( &block )  # :yields: uuid, properties_hash
		@metadata.each( &block )
	end


end # class ThingFish::MemoryMetaStore

# vim: set nosta noet ts=4 sw=4:

