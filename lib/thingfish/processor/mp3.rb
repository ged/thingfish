# -*- ruby -*-
#encoding: utf-8

require 'mp3info'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/processor' unless defined?( Thingfish::Processor )


# An in-memory metastore for testing and tryout purposes.
class Thingfish::Processor::MP3 < Thingfish::Processor
	extend Loggability

	# Loggability API -- log to the :thingfish logger
	log_to :thingfish


	### Synchronous processor API -- extract metadata from uploaded MP3s
	def handle_request( request )
	end

end # class Thingfish::Processor::MP3

