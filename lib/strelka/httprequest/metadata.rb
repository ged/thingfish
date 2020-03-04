# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen_string_literal: true

require 'strelka/constants'
require 'strelka/httprequest' unless defined?( Strelka::HTTPRequest )

require 'thingfish'
require 'thingfish/mixins'


# The mixin that adds methods to Strelka::HTTPRequest for Thingfish metadata.
#
#   request.metadata
#   request.add_metadata
#
module Strelka::HTTPRequest::Metadata
	include Strelka::Constants,
	        Thingfish::Normalization


	### Set up some data structures for metadata.
	def initialize( * )
		super

		@metadata = {}
		@related_resources = {}
	end


	######
	public
	######

	# The Hash of Thingfish metadata associated with the request
	attr_reader :metadata

	# The Hash of related resources
	attr_reader :related_resources


	### Merge the metadata in the given +metadata+ hash into the request's current
	### metadata.
	def add_metadata( metadata )
		self.log.debug "Adding metadata to the request: %p" % [ metadata ]
		metadata = normalize_keys( metadata )
		self.metadata.merge!( metadata )
	end


	### Add a resource that's related to the one in the request.
	def add_related_resource( io, metadata )
		metadata = normalize_keys( metadata )
		metadata.merge!( self.extract_related_metadata(io) )
		self.log.debug "Adding related resource: %p %p" % [ io, metadata ]
		self.related_resources[ io ] = metadata
	end


	### Extract some default metadata from related resources.
	def extract_related_metadata( io )
		metadata = {}

		metadata['extent'] = io.size

		return metadata
	end

end

