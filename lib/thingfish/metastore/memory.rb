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


	### Save the +metadata+ for the specified +oid+.
	def save( oid, metadata )
		oid = self.normalize_oid( oid )
		self.log.debug "Saving %d metadata attributes for OID %s" % [ metadata.length, oid ]
		@storage[ oid ] = metadata.dup
	end


	### Fetch the data corresponding to the given +oid+ as a Hash-ish object.
	def fetch( oid, *keys )
		oid = self.normalize_oid( oid )
		if keys.empty?
			self.log.debug "Fetching metadata for OID %s" % [ oid ]
			return @storage[ oid ]
		else
			self.log.debug "Fetching metadata for %p for OID %s" % [ keys, oid ]
			data = @storage[ oid ] or return []
			return data.values_at( *keys )
		end
	end


	### Update the metadata for the given +oid+ with the specified +values+ hash.
	def merge( oid, values )
		oid = self.normalize_oid( oid )
		@storage[ oid ].merge!( values )
	end

end # class Thingfish::MemoryMetastore

