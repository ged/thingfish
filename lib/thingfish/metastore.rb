# -*- ruby -*-
# frozen_string_literal: true

require 'pluggability'
require 'strelka'
require 'strelka/mixins'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/mixins'

# The base class for storage mechanisms used by Thingfish to store its data
# blobs.
class Thingfish::Metastore
	extend Pluggability,
	       Strelka::AbstractClass
	include Thingfish::Normalization


	# Pluggability API -- set the prefix for implementations of Metastore
	plugin_prefixes 'thingfish/metastore'

	# AbstractClass API -- register some virtual methods that must be implemented
	# in subclasses
	pure_virtual :oids,
	             :each_oid,
	             :save,
	             :search,
	             :fetch,
	             :fetch_value,
	             :fetch_related_oids,
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


	### Provide transactional consistency to the provided block. Concrete metastores should
	### override this if they can implement it. By default it's a no-op.
	def transaction
		yield
	end


end # class Thingfish::Metastore

