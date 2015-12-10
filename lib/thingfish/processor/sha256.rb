# -*- ruby -*-
#encoding: utf-8

require 'digest/sha2'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/processor' unless defined?( Thingfish::Processor )


# Calculate and store a sha256 checksum for a resource.
class Thingfish::Processor::SHA256 < Thingfish::Processor
	extend Loggability

	# The chunk size to read
	CHUNK_SIZE = 32 * 1024

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish

	# The list of handled types
	handled_types '*/*'


	### Synchronous processor API -- generate a checksum during upload.
	def on_request( request )
		digest = Digest::SHA256.new
		buf = ''

		while request.body.read( CHUNK_SIZE, buf )
			digest.update( buf )
		end

		request.body.rewind
		request.add_metadata( :checksum => digest.hexdigest )
	end

end # class Thingfish::Processor::SHA256

