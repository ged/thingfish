# -*- ruby -*-
#encoding: utf-8

require 'thingfish' unless defined?( ThingFish )
require 'thingfish/datastore' unless defined?( ThingFish::Datastore )



# An in-memory datastore for testing and tryout purposes.
class ThingFish::MemoryDatastore < ThingFish::Datastore
	extend Loggability


	# Loggability API -- log to the :thingfish logger
	log_to :thingfish



end # class ThingFish::MemoryDatastore

