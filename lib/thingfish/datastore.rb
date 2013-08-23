# -*- ruby -*-
#encoding: utf-8

require 'securerandom'
require 'pluggability'
require 'stringio'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/mixins'

# The base class for storage mechanisms used by Thingfish to store its data
# blobs.
class Thingfish::Datastore
	extend Pluggability,
	       Thingfish::AbstractClass
	include Enumerable,
	        Thingfish::OIDUtilities


	# Pluggability API -- set the prefix for implementations of Datastore
	plugin_prefixes 'thingfish/datastore'

	# AbstractClass API -- register some virtual methods that must be implemented
	# in subclasses
	pure_virtual :save,
	             :replace,
	             :fetch,
	             :each,
	             :include?,
	             :remove


	# :TODO: Make a utility method that provides normalization for IO handling
	#  (restore .pos, etc.)
	# def with_io( io ) ... end

	### Return a representation of the object as a String suitable for debugging.
	def inspect
		return "#<%p:%#016x>" % [
			self.class,
			self.object_id * 2
		]
	end

end # class Thingfish::Datastore

