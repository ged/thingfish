# -*- ruby -*-
# frozen_string_literal: true

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
		request.add_metadata( :checksum => self.checksum(request.body) )
		request.related_resources.each_pair do |io, metadata|
			metadata[ :checksum ] = self.checksum( io )
		end
	end


	#########
	protected
	#########

	### Given an +io+, return a sha256 checksum of it's contents.
	def checksum( io )
		digest = Digest::SHA256.new
		buf = String.new

		while io.read( CHUNK_SIZE, buf )
			digest.update( buf )
		end

		io.rewind
		return digest.hexdigest
	end

end # class Thingfish::Processor::SHA256

