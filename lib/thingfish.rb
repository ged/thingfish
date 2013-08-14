#!/usr/bin/env ruby

require 'strelka'
require 'strelka/app'

#
# Network-accessable datastore service
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
class Thingfish < Strelka::App

	# Loggability API -- log all Thingfish-related stuff to a separate logger
	log_as :thingfish


	# Package version
	VERSION = '0.5.0'

	# Version control revision
	REVISION = %q$Revision$

	# Configurability API -- set config defaults
	CONFIG_DEFAULTS = {
		datastore: 'memory',
		metastore: 'memory'
	}

	require 'thingfish/mixins'
	extend MethodUtilities


	### Get the library version. If +include_buildnum+ is true, the version string will
	### include the VCS rev ID.
	def self::version_string( include_buildnum=false )
		vstring = "%s %s" % [ self.name, VERSION ]
		vstring << " (build %s)" % [ REVISION[/: ([[:xdigit:]]+)/, 1] || '0' ] if include_buildnum
		return vstring
	end


	##
	# Configurability API
	config_key :thingfish

	# The configured datastore type
	singleton_attr_accessor :datastore

	# The configured metastore type
	singleton_attr_accessor :metastore


	### Configurability API -- install the configuration
	def self::configure( config=nil )
		config ||= self.defaults
		self.datastore = config[:datastore] || 'memory'
		self.metastore = config[:metastore] || 'memory'
	end


	### Set up blerghh...
	def initialize( * )
		super

		@datastore = Thingfish::Datastore.create( self.class.datastore )
		@metastore = Thingfish::Metastore.create( self.class.metastore )
	end


	######
	public
	######

	# The datastore
	attr_reader :datastore

	# The metastore
	attr_reader :metastore


	#
	# Global parmas
	#
	plugin :parameters
	param :uuid


	#
	# Routing
	#
	plugin :routing
	router :exclusive

	# GET /«uuid»
	# Fetch an object by ID
	get ':uuid' do |req|
		uuid = req.params[:uuid]
		object = self.datastore.fetch( uuid ) or
			finish_with HTTP::NOT_FOUND, "no such object"
		metadata = self.metastore.fetch( uuid )

		res = req.response
		res.body = object
		res.content_type = metadata[:format]

		return res
	end


	# POST /
	# Upload a new object.
	post do |req|
		metadata = {
			:useragent     => req.headers.user_agent,
			:extent        => req.headers.content_length,
			:uploadaddress => req.remote_ip,
			:format        => req.content_type
		}

		uuid = self.datastore.save( req.body )
		self.metastore.save( uuid, metadata )

		url = req.base_uri.dup
		url.path += uuid

		res = req.response
		res.headers.location = url
		res.status = HTTP::CREATED

		return res
	end


	require 'thingfish/datastore'
	require 'thingfish/metastore'

end # class Thingfish

# vim: set nosta noet ts=4 sw=4:
