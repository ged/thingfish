# -*- ruby -*-
#encoding: utf-8

require 'pluggability'

require 'thingfish' unless defined?( Thingfish )


# Thingfish asset processor base class.
class Thingfish::Processor
	extend Pluggability


	plugin_prefixes 'processor'


	### Process the data and/or metadata in the +request+.
	def process_request( request )
		# No-op by default
	end


	### Process the data and/or metadata in the +response+.
	def process_response( response )
		# No-op by default
	end

end # class Thingfish::Processor

