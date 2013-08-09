# -*- ruby -*-
#encoding: utf-8

require 'securerandom'
require 'pluggability'
require 'stringio'

require 'thingfish' unless defined?( ThingFish )
require 'thingfish/mixins'

# The base class for storage mechanisms used by ThingFish to store its data
# blobs.
class ThingFish::Datastore
	extend Pluggability,
	       ThingFish::AbstractClass
	include Enumerable


	# Pluggability API -- set the prefix for implementations of Datastore
	plugin_prefixes 'thingfish/datastore'

	# AbstractClass API -- register some virtual methods that must be implemented
	# in subclasses
	pure_virtual :create_object,
	             :fetch_object,
	             :each

	alias_method :[]=, :create_object
	alias_method :[], :fetch_object


	#########
	protected
	#########

	### Generate a new object ID.
	def make_object_id
		return SecureRandom.uuid
	end

end # class ThingFish::Datastore

