# -*- ruby -*-
#encoding: utf-8

require 'digest/sha2'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/processor' unless defined?( Thingfish::Processor )


# Calculate and store a sha256 checksum for a resource.
class Thingfish::Processor::SHA256 < Thingfish::Processor
	extend Loggability

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish

	# The list of handled types
	handled_types '*/*'


	### Synchronous processor API -- generate a checksum during upload.
	def on_request( request )
		digest = Digest::SHA256.file( request.body.path ).hexdigest
		request.add_metadata( :checksum => digest )
	end

end # class Thingfish::Processor::SHA256

