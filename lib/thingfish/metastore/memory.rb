# -*- ruby -*-
#encoding: utf-8

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/metastore' unless defined?( Thingfish::Metastore )



# An in-memory metastore for testing and tryout purposes.
class Thingfish::Metastore::Memory < Thingfish::Metastore
	extend Loggability
	include Thingfish::Normalization

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish


	### Create a new MemoryMetastore, using the given +storage+ object to store
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
		oid = normalize_oid( oid )
		@storage[ oid ] = metadata.dup
	end


	### Fetch the data corresponding to the given +oid+ as a Hash-ish object.
	def fetch( oid, *keys )
		oid = normalize_oid( oid )
		metadata = @storage[ oid ] or return nil

		if keys.empty?
			self.log.debug "Fetching metadata for OID %s" % [ oid ]
			return metadata.dup
		else
			self.log.debug "Fetching metadata for %p for OID %s" % [ keys, oid ]
			keys = normalize_keys( keys )
			values = metadata.values_at( *keys )
			return Hash[ [keys, values].transpose ]
		end
	end


	### Fetch the value of the metadata associated with the given +key+ for the
	### specified +oid+.
	def fetch_value( oid, key )
		oid = normalize_oid( oid )
		key = normalize_key( key )
		data = @storage[ oid ] or return nil

		return data[ key ]
	end


	### Fetch UUIDs related to the given +oid+.
	def fetch_related_uuids( oid )
		oid = normalize_oid( oid )
		self.log.debug "Fetching UUIDs of resources related to %s" % [ oid ]
		return self.search( :criteria => {:relation => oid}, :include_related => true )
	end


	### Search the metastore for UUIDs which match the specified +criteria+ and
	### return them as an iterator.
	def search( options={} )
		ds = @storage.each_key
		self.log.debug "Starting search with %p" % [ ds ]

		ds = self.omit_related_resources( ds, options )
		ds = self.apply_search_criteria( ds, options )
		ds = self.apply_search_order( ds, options )
		ds = self.apply_search_direction( ds, options )
		ds = self.apply_search_limit( ds, options )

		return ds.to_a
	end


	### Omit related resources from the search dataset +ds+ unless the given
	### +options+ specify otherwise.
	def omit_related_resources( ds, options )
		unless options[:include_related]
			ds = ds.reject {|uuid| @storage[uuid]['relationship'] }
		end
		return ds
	end


	### Apply the search :criteria from the specified +options+ to the collection
	### in +ds+ and return the modified dataset.
	def apply_search_criteria( ds, options )
		if (( criteria = options[:criteria] ))
			criteria.each do |field, value|
				self.log.debug "  applying criteria: %p => %p" % [ field.to_s, value ]
				ds = ds.select {|uuid| @storage[uuid][field.to_s] == value }
			end
		end

		return ds
	end


	### Apply the search :order from the specified +options+ to the collection in
	### +ds+ and return the modified dataset.
	def apply_search_order( ds, options )

		# :FIXME: I can't think of a way to handle the case where one of the sort fields
		# is nil in a non-gross way. So instead, just turn ordering off.

		# if (( order_fields = options[:order] ))
		#	fields = order_fields.split( /\s*,\s*/ )
		#	self.log.debug "  applying order by fields: %p" % [ fields ]
		#	ds = ds.to_a.sort_by do |uuid|
		#		sortvals = @storage[uuid].values_at(*fields).map {|val| val || ''}
		#		self.log.debug "    sortvals: %p" % [ sortvals ]
		#		sortvals
		#	end
		# end

		return ds
	end


	### Apply the search :direction from the specified +options+ to the collection
	### in +ds+ and return the modified dataset.
	def apply_search_direction( ds, options )
		ds.reverse! if options[:direction] && options[:direction] == 'desc'
		return ds
	end


	### Apply the search :limit from the specified +options+ to the collection in
	### +ds+ and return the modified dataset.
	def apply_search_limit( ds, options )
		if (( limit = options[:limit] ))
			self.log.debug "  limiting to %s results" % [ limit ]
			offset = options[:offset] || 0
			ds = ds.to_a.slice( offset, limit )
		end

		return ds
	end


	### Update the metadata for the given +oid+ with the specified +values+ hash.
	def merge( oid, values )
		oid = normalize_oid( oid )
		values = normalize_keys( values )
		@storage[ oid ].merge!( values )
	end


	### Remove all metadata associated with +oid+ from the Metastore.
	def remove( oid, *keys )
		oid = normalize_oid( oid )
		if keys.empty?
			@storage.delete( oid )
		else
			keys = normalize_keys( keys )
			@storage[ oid ].delete_if {|key, _| keys.include?(key) }
		end
	end


	### Remove all metadata associated with +oid+ except for the specified +keys+.
	def remove_except( oid, *keys )
		oid = normalize_oid( oid )
		keys = normalize_keys( keys )
		@storage[ oid ].keep_if {|key,_| keys.include?(key) }
	end


	### Returns +true+ if the metastore has metadata associated with the specified +oid+.
	def include?( oid )
		oid = normalize_oid( oid )
		return @storage.include?( oid )
	end


	### Returns the number of objects the store contains.
	def size
		return @storage.size
	end

end # class Thingfish::Metastore::Memory

