#!/usr/bin/ruby
# 
# The base metastore class for ThingFish
# 
# == Synopsis
# 
#   require 'thingfish/metastore'
#
#   class MyMetaStore < ThingFish::MetaStore
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
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'pluginfactory'
require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/exceptions'
	
# The base class for ThingFish MetaStore plugins. Concrete plugin implementations are required to
# implement the following interface:
# 
# [<tt>set_property( uuid, propname, value )</tt>]
#   Set the property associated with +uuid+ specified by +propname+ to the given +value+.
# [<tt>set_properties( uuid, hash )</tt>]
#   Set the properties associated with the given +uuid+ to those in the provided +hash+.
# [<tt>get_property( uuid, propname )</tt>]
#   Return the property associated with +uuid+ specified by +propname+. Returns +nil+ if no such 
#   property exists.
# [<tt>get_properties( uuid )</tt>]
#   Get the set of properties associated with the given +uuid+ as a hash keyed by property names 
#   as symbols.
# [<tt>has_uuid?( uuid )</tt>]
#   Returns +true+ if the given +uuid+ exists in the metastore.
# [<tt>has_property?( uuid, propname )</tt>]
#   Returns +true+ if the given +uuid+ has a property +propname+.
# [<tt>delete_property( uuid, propname )</tt>]
#   Removes the property +propname+ associated with the given +uuid+.
# [<tt>delete_properties( uuid )</tt>]
#   Removes all properties associated with the given +uuid+.
# [<tt>get_all_property_keys()</tt>]
#   Return an Array of all property keys in the store.
# [<tt>get_all_property_values()</tt>]
#   Return a uniquified Array of all values in the metastore for the specified +key+.
# [<tt>find_by_exact_properties()</tt>]
#   Return an array of uuids whose metadata matched the criteria
#   specified by +hash+. The criteria should be key-value pairs which describe
#   exact metadata pairs.  This is an exact match search.
# [<tt>find_by_matching_properties()</tt>]
#   Return an array of uuids whose metadata matched the criteria
#   specified by +hash+. The criteria should be key-value pairs which describe
#   exact metadata pairs.  This is a wildcard search.
#
class ThingFish::MetaStore
	include PluginFactory,
	        ThingFish::Loggable,
	        ThingFish::AbstractClass,
			ThingFish::HtmlInspectableObject


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Proxy class for metadata operations for a given resource.
	class ResourceProxy
		include Enumerable
		
		### Create a new ResourceProxy for the given +uuid+ that will perform
		### operations on the given +store+.
		def initialize( uuid, store )
			@uuid = uuid
			@store = store
		end


		######
		public
		######

		# The associated UUID
		attr_reader :uuid


		### Enumerable interface: Call the supplied block once for each property
		### associated with the proxied resource.
		def each( &block )
			@store.get_properties( @uuid ).each( &block )
		end


		### Adds the contents of +hash+ to the values for the referenced UUID, overwriting entries
		### with duplicate keys.
		def update( hash )
			merged = @store.get_properties( @uuid ).merge( hash )
			@store.set_properties( @uuid, merged )
		end
		alias_method :merge!, :update
		

		### Returns true if the +other+ object is equivalent to the receiver
		### (they have the same UUID).
		def ==( other )
			self.uuid == other.uuid
		rescue MethodError
			return false
		end
		
		
		#########
		protected
		#########

		### Proxy method for calling methods that correspond to keys.
		def method_missing( sym, *args )
			case sym.to_s
			when /^(?:has_)(\w+)\?$/
				propname = $1
				return @store.has_property?( @uuid, propname )

			when /^(\w+)=$/
				propname = $1
				return @store.set_property( @uuid, propname, *args )
				
			else
				propname = sym.to_s
				return @store.get_property( @uuid, propname )
			end
		end
		
	end # class ResourceProxy

	

	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### PluginFactory interface: Return an Array of prefixes to use when searching 
	### for derivatives.
	def self::derivative_dirs
		['thingfish/metastore']
	end
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new ThingFish::MetaStore object.
	def initialize( options={} )
		@options = options
		@proxy_class = ResourceProxy
		super()
	end


	######
	public
	######

	# The class of object to use as the proxy for a given object's metadata
	attr_accessor :proxy_class
	
	
	### Return a ResourceProxy for the given +uuid+ that can used to get, set, and
	### query metadata about the resource associated with +uuid+.
	def []( uuid )
		raise ThingFish::PluginError,
			"%s did not call its parent class's initializer" % [self.class.name] unless
			@proxy_class
		return @proxy_class.new( uuid.to_s, self )
	end


	### Execute a block in the scope of a transaction, committing it when the block returns.
	### If an exception is raised in the block, the transaction is aborted. This is a
	### no-op by default, but left to specific metastores to provide a functional 
	### implementation if it is useful/desired.
	def transaction
		yield
	end
	

	### Mandatory MetaStore API
	virtual :has_uuid?,
		:has_property?,
		:set_property,
		:set_properties,
		:get_property,
		:get_properties,
		:delete_property,
		:delete_properties,
		:get_all_property_keys,
		:get_all_property_values,
		:find_by_exact_properties,
		:find_by_matching_properties

end # class ThingFish::MetaStore


# vim: set nosta noet ts=4 sw=4:

