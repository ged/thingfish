# -*- ruby -*-
#encoding: utf-8

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/datastore' unless defined?( Thingfish::Datastore )



# An in-memory datastore for testing and tryout purposes.
class Thingfish::MemoryDatastore < Thingfish::Datastore
	extend Loggability

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish


	### Create a new MemoryDatastore, using the given +storage+ object to store
	### data in. The +storage+ should quack like a Hash.
	def initialize( storage={} )
		@storage = storage
	end


	### Save the +data+ read from the specified +io+ and return an ID that can be
	### used to fetch it later.
	def save( io )
		oid = self.make_object_id
		offset = io.pos
		data = io.read.dup

		self.log.debug "Saving %d bytes of data under OID %s" % [ data.bytesize, oid ]
		@storage[ oid ] = data

		io.pos = offset
		return oid
	end


	### Replace the existing object associated with +oid+ with the data read from the
	### given +io+.
	def replace( oid, io )
		offset = io.pos
		data = io.read.dup

		self.log.debug "Replacing data under OID %s with %d bytes" % [ oid, data.bytesize ]
		@storage[ oid ] = data

		io.pos = offset
		return true
	end


	### Fetch the data corresponding to the given +oid+ as an IOish object.
	def fetch( oid )
		self.log.debug "Fetching data for OID %s" % [ oid ]
		data = @storage[ oid ] or return nil
		return StringIO.new( data )
	end

end # class Thingfish::MemoryDatastore

