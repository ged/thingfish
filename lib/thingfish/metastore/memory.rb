# -*- ruby -*-
#encoding: utf-8

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/metastore' unless defined?( Thingfish::Metastore )



# An in-memory metastore for testing and tryout purposes.
class Thingfish::MemoryMetastore < Thingfish::Metastore
	extend Loggability

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish


	### Create a new MemoryDatastore, using the given +storage+ object to store
	### data in. The +storage+ should quack like a Hash.
	def initialize( storage={} )
		@storage = storage
	end


	##
	# The raw Hash of metadata
	attr_reader :storage


	### Return an Array of all of the store's keys.
	def keys
		return @storage.keys
	end


	### Iterate over each of the store's keys, yielding to the block if one is given
	### or returning an Enumerator if one is not.
	def each_key( &block )
		return @storage.each_key( &block )
	end


	### Save the +metadata+ Hash for the specified +oid+.
	def save( oid, metadata )
		oid = self.normalize_oid( oid )
		@storage[ oid ] = metadata.dup
	end


	### Fetch the data corresponding to the given +oid+ as a Hash-ish object.
	def fetch( oid, *keys )
		oid = self.normalize_oid( oid )
		metadata = @storage[ oid ] or return nil

		if keys.empty?
			self.log.debug "Fetching metadata for OID %s" % [ oid ]
			return metadata.dup
		else
			self.log.debug "Fetching metadata for %p for OID %s" % [ keys, oid ]
			values = metadata.values_at( *keys )
			return Hash[ [keys, values].transpose ]
		end
	end


	### Fetch the value of the metadata associated with the given +key+ for the
	### specified +oid+.
	def fetch_value( oid, key )
		oid = self.normalize_oid( oid )
		data = @storage[ oid ] or return nil

		return data[ key ]
	end


	### Search the metastore for UUIDs which match the specified +criteria+ and
	### return them as an iterator.
	def search( criteria={} )
		ds = @storage.each_key

		if order_fields = criteria[:order]
			fields = order_fields.split( /\s*,\s*/ )
			ds = ds.order_by {|uuid| @storage[uuid].values_at(*fields) }
		end

		ds = ds.reverse if criteria[:direction] && criteria[:direction] == 'desc'

		if (( limit = criteria[:limit] ))
			offset = criteria[:offset] || 0
			ds = ds.to_a.slice( offset, limit )
		end

		return ds.to_a
	end


	### Update the metadata for the given +oid+ with the specified +values+ hash.
	def merge( oid, values )
		oid = self.normalize_oid( oid )
		@storage[ oid ].merge!( values )
	end


	### Remove all metadata associated with +oid+ from the Metastore.
	def remove( oid, *keys )
		oid = self.normalize_oid( oid )
		if keys.empty?
			@storage.delete( oid )
		else
			keys = keys.map( &:to_s )
			@storage[ oid ].delete_if {|key, _| keys.include?(key) }
		end
	end


	### Remove all metadata associated with +oid+ except for the specified +keys+.
	def remove_except( oid, *keys )
		oid = self.normalize_oid( oid )
		keys = keys.map( &:to_s )
		@storage[ oid ].keep_if {|key,_| keys.include?(key) }
	end


	### Returns +true+ if the metastore has metadata associated with the specified +oid+.
	def include?( oid )
		oid = self.normalize_oid( oid )
		return @storage.include?( oid )
	end


	### Returns the number of objects the store contains.
	def size
		return @storage.size
	end

end # class Thingfish::MemoryMetastore

