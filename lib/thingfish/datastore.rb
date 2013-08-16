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
	include Enumerable


	# Pluggability API -- set the prefix for implementations of Datastore
	plugin_prefixes 'thingfish/datastore'

	# AbstractClass API -- register some virtual methods that must be implemented
	# in subclasses
	pure_virtual :save,
	             :replace,
	             :fetch,
	             :each


	#########
	protected
	#########

	### Generate a new object ID.
	def make_object_id
		return SecureRandom.uuid
	end

	# def with_io( io ) ... end

end # class Thingfish::Datastore

