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


	### Save the metadata for the specified +oid+.
	### +args+ can ether be a Hash of metadata pairs, or a single key and value.
	###
	###     save( oid, {} )
	###     save( oid, key, value )
	###
	def save( oid, *args )
		oid = self.normalize_oid( oid )

		metadata = args.shift

		if metadata.is_a?( Hash )
			@storage[ oid ] = metadata.dup
		else
			@storage[ oid ] ||= {}
			@storage[ oid ][ metadata.to_s ] = args.shift
		end
	end


	### Fetch the data corresponding to the given +oid+ as a Hash-ish object.
	def fetch( oid, *keys )
		oid = self.normalize_oid( oid )
		if keys.empty?
			self.log.debug "Fetching metadata for OID %s" % [ oid ]
			return @storage[ oid ]
		elsif keys.length == 1
			data = @storage[ oid ] or return nil
			return data[ keys.first ]
		else
			self.log.debug "Fetching metadata for %p for OID %s" % [ keys, oid ]
			data = @storage[ oid ] or return nil
			return data.values_at( *keys )
		end
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
	def remove( oid )
		oid = self.normalize_oid( oid )
		@storage.delete( oid )
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

