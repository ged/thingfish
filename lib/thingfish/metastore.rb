#!/usr/bin/env ruby

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
#   Set the properties associated with the given +uuid+ to those in the provided +hash+,
#   eliminating any others already set.
# [<tt>update_properties( uuid, hash )</tt>]
#   Merge the properties in the provided hash with those associated with the given +uuid+.
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
# [<tt>delete_properties( uuid, *properties )</tt>]
#   Removes the specified +properties+ associated with the given +uuid+.
# [<tt>delete_resource( uuid )</tt>]
#   Removes all properties associated with the given +uuid+, as well as the entry itself.
# [<tt>get_all_property_keys()</tt>]
#   Return an Array of all property keys in the store.
# [<tt>get_all_property_values( key )</tt>]
#   Return a uniquified Array of all values in the metastore for the specified +key+.
# [<tt>dump_store()</tt>]
#   Return a Hash of all metadata in the store, keyed by UUID.
# [<tt>load_store( hash )</tt>]
#   Replace the contents of the store with the given hash of metadata, keyed by UUID.
# [<tt>each_resource()</tt>]
#   Iterates over the store, yielding each UUID and a hash of associated properties.
# [<tt>clear()</tt>]
#   Delete all data from the store.
#
# Simple metastore plugins should either implement the below methods, or override
# the #find_by_exact_properties() and #find_by_matching_properties() methods.
#
# [<tt>find_exact_uuids()</tt>]
#	Return a hash keyed on uuid whose metadata values matched
#	the criteria specified by +key+ and +value+. This is an exact match search.
# [<tt>find_matching_uuids()</tt>]
#	Return a hash keyed on uuid whose metadata values matched
#	the criteria specified by +key+ and +value+. This is a wildcard search.
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
class ThingFish::MetaStore
	include Enumerable,
	        PluginFactory,
	        ThingFish::Loggable,
	        ThingFish::AbstractClass,
	        ThingFish::HtmlInspectableObject


	# Keys which should not be manually updated
	SYSTEM_METADATA_KEYS = [ :extent, :checksum ]


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
			@store.update_properties( @uuid,  hash )
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
	def initialize( datadir, spooldir, options={} )
		@datadir     = datadir
		@spooldir    = spooldir
		@options     = options
		@proxy_class = ResourceProxy

		super()
	end


	######
	public
	######

	# The directory this metastore will store stuff in (if it uses files)
	attr_reader :datadir

	# The directory this metastore will use for temporary files
	attr_reader :spooldir

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


	### Perform any startup tasks that should take place after the daemon has an opportunity
	### to daemonize and switch effective user.  This can be overridden from child classes.
	def on_startup
		# default no-op
	end


	### Execute a block in the scope of a transaction, committing it when the block returns.
	### If an exception is raised in the block, the transaction is aborted. This is a
	### no-op by default, but left to specific metastores to provide a functional
	### implementation if it is useful/desired.
	def transaction
		yield
	end


	### Merge the properties associated with the specified +uuid+ with the given +props+
	### after eliminating any that are necessary for filestore consistency.
	def update_safe_properties( uuid, props )
		props = self.prune_system_properties( props )
		self.update_properties( uuid, props )
	end


	### Set the properties associated with the specified +uuid+ to the given +props+
	### after eliminating any that are necessary for filestore consistency.
	def set_safe_properties( uuid, props )
		props = self.prune_system_properties( props )
		safekeys = self.prune_system_properties( self.get_all_property_keys )
		self.delete_properties( uuid, *safekeys )
		self.update_properties( uuid, props )
	end


	### Set the value of the metadata +key+ associated with the given +uuid+ to +value+, unless it's
	### a property that is used by the system, in which case it is silently ignored.
	def set_safe_property( uuid, key, value )
		props = self.prune_system_properties( [key] )
		raise ThingFish::MetaStoreError,
			"property '#{key}' cannot be updated, as it is used by the system" if props.empty?
		self.set_property( uuid, key, value )
	end


	### Delete the given +props+ associated with the specified +uuid+ after eliminating any
	### that are necessary for filestore consistency.
	def delete_safe_properties( uuid, *props )
		props = self.prune_system_properties( props )
		self.delete_properties( uuid, *props )
	end


	### Delete the given +key+ from the metadata associated with the specified +uuid+ unless it's
	### one of the properties used by the system, in which case a ThingFish::MetaStoreError is
	### raised.
	def delete_safe_property( uuid, key )
		props = self.prune_system_properties( key => nil )
		raise ThingFish::MetaStoreError,
			"property '#{key}' cannot be deleted, as it is used by the system" if props.empty?
		self.delete_property( uuid, key )
	end


	### Return an array of tuples of the form:
	###   [ UUID, { :key => «value» } ]
	### whose metadata exactly matches the key-value pairs in +hash+. If the
	### optional +order+, +limit+, and +offset+ are given, use them to limit the result set.
	def find_by_exact_properties( hash, order=[], limit=DEFAULT_LIMIT, offset=0 )
		self.intersect_each_tuple( hash, order, limit, offset ) do |key,value|
			self.find_exact_uuids( key, value )
		end
	end


	### Return an array of tuples of the form:
	###   [ UUID, { :key => «value» } ]
	### whose metadata wildcard-matches the key-value pairs in +hash+. If the
	### optional +order+, +limit+, and +offset+ are given, use them to limit the result set.
	def find_by_matching_properties( hash, order=[], limit=DEFAULT_LIMIT, offset=0 )
		self.intersect_each_tuple( hash, order, limit, offset ) do |key,value|
			self.find_matching_uuids( key, value )
		end
	end


	### Yield the metadata in the store to the provided block one resource at a time.
	def migrate
		self.each_resource do |uuid, properties|
			yield( uuid, properties )
		end
	end


	### Migrate all the data from the specified +other_metastore+, replacing all the
	### current values.
	def migrate_from( other_metastore )
		self.transaction do
			self.clear

			self.log.info "Migrating metadata from %s:0x%08x to %s:0x%08x" % [
				other_metastore.class.name,
				other_metastore.object_id * 2,
				self.class.name,
				self.object_id * 2
			  ]
			other_metastore.migrate do |uuid, properties|
				self.log.info "  copying %s: %d properties" % [ uuid, properties.length ]
				self.set_properties( uuid, properties )
			end
		end
	end



	### Mandatory MetaStore API
	virtual :has_uuid?,
		:has_property?,
		:set_property,
		:set_properties,
		:update_properties,
		:get_property,
		:get_properties,
		:delete_property,
		:delete_properties,
		:delete_resource,
		:get_all_property_keys,
		:get_all_property_values,
		:find_exact_uuids,
		:find_matching_uuids,
		:dump_store,
		:load_store,
		:each_resource,
		:clear


	#########
	protected
	#########

	### Return a copy of the specified +props+ hash after eliminating any used by the
	### system (as defined by SYSTEM_METADATA_KEYS).
	def prune_system_properties( props )
		props = props.dup

		SYSTEM_METADATA_KEYS.each do |key|
			props.delete( key )
			props.delete( key.to_s )
		end

		return props
	end


	### Transform the specified +glob+ pattern to a Regexp suitable for matching
	### against values in the metastore. Currently only supports '*' globbing.
	def glob_to_regexp( glob )
		pat = glob.to_s.gsub( '*', '.*' )
		return Regexp.new( '^' + pat + '$', Regexp::IGNORECASE )
	end


	### Remove nil values from the given +hash+, then yield key/value pairs as tuples. The 
	### block is expected to return a hash keyed by UUID of resources that match the yielded tuple. 
	### The returned UUID sets are then intersected, and any UUIDs common to all matched 
	### tuples are returned.
	def intersect_each_tuple( hash, order, limit, offset )

		# Trim nil values out of the hash then make a search pair for each key/value combination.
		#   { 'format' => ['image/png', 'image/jpeg' ], 'extent' => 3400 }
		# becomes:
		#   [ ['format', 'image/png'], ['format', 'image/jpeg'], ['extent', 3400] ]
		tuples = hash.reject {|k,v| v.nil? }.inject([]) do |ary, pair|
			key,vals = *pair
			[vals].flatten.each do |val|
				ary << [ key, val ]
			end

			ary
		end

		# Iterate over each search pair, searching for matches, then narrowing the results by
		# intersecting the previous resultset with the current one.
		resultset = tuples.inject({}) do |union_resultset, pair|
			key, value = *pair
			key = key.to_s

			matching_set = yield( key, value )
			union_resultset.merge!( matching_set )
			union_resultset.delete_if {|uuid, _| !matching_set.key?(uuid) }
			union_resultset
		end

		return [] if resultset.empty?

		# Do ordering
		tuples = resultset.sort_by do |uuid, props|
			# :TODO: Find some better stand-in for Nil than the empty string?
			props.values_at( *order ).collect {|val| val || '' } + [ uuid ]
		end

		if limit.nonzero?
			return tuples[ offset, limit ]
		else
			return tuples[ offset..-1 ]
		end
	end

end # class ThingFish::MetaStore


# vim: set nosta noet ts=4 sw=4:

