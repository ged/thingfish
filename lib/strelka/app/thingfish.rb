# -*- ruby -*-
#encoding: utf-8

require 'strelka'
require 'strelka/plugins'
require 'strelka/httprequest/metadata'

require 'thingfish'


# A Strelka plugin for setting up requests to be able to carry Thingfish metadata
# with it.
module Strelka::App::Thingfish
	extend Strelka::Plugin


	run_outside :routing, :filters
	run_inside :templating, :parameters


	### Extension callback -- extend the HTTPRequest classes with Metadata
	### support when this plugin is loaded.
	def self::included( object )
		self.log.debug "Extending Request with Metadata mixins"
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Metadata }
		super
	end


	### Start content-negotiation when the response has returned.
	def handle_request( request )
		self.log.debug "[:metadata] Attaching Thingfish metadata to request."
		super
	end


end # module Strelka::App::Thingfish

