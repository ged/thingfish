# -*- ruby -*-
#encoding: utf-8

require 'pluggability'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/mixins'

# The base class for storage mechanisms used by Thingfish to store its data
# blobs.
class Thingfish::Metastore
	extend Pluggability,
	       Thingfish::AbstractClass
	include Thingfish::OIDUtilities


	# Pluggability API -- set the prefix for implementations of Metastore
	plugin_prefixes 'thingfish/metastore'

	# AbstractClass API -- register some virtual methods that must be implemented
	# in subclasses
	pure_virtual :keys,
	             :each_key,
	             :save,
	             :search,
	             :fetch,
	             :merge,
	             :include?,
	             :remove,
	             :remove_except,
				 :size

	### Return a representation of the object as a String suitable for debugging.
	def inspect
		return "#<%p:%#016x %d objects>" % [
			self.class,
			self.object_id * 2,
			self.size
		]
	end

end # class Thingfish::Metastore

