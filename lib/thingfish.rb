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

	# Metadata keys which aren't directly modifiable via the REST API
	PROTECTED_METADATA_KEYS = %w[
		format
		extent
	]


	require 'thingfish/mixins'
	require 'thingfish/datastore'
	require 'thingfish/metastore'
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


	########################################################################
	### P L U G I N S
	########################################################################

	#
	# Global parmas
	#
	plugin :parameters
	param :uuid
	param :key, :word


	#
	# Content negotiation
	#
	plugin :negotiation


	#
	# Routing
	#
	plugin :routing
	router :exclusive

	#
	# Filters
	#
	plugin :filters

	### Modify outgoing headers on all responses to include version info.
	###
	filter :response do |res|
		res.headers.x_thingfish = Thingfish.version_string( true )
	end


	# GET /
	# Return various information about the handler configuration.
	get do |req|
		res  = req.response
		info = {
			:version   => Thingfish.version_string( true ),
			:metastore => self.metastore.class.name,
			:datastore => self.datastore.class.name
		}

		res.for( :text, :json, :yaml ) { info }
		return res
	end


	#
	# Datastore routes
	#

	# GET /«uuid»
	# Fetch an object by ID
	get ':uuid' do |req|
		uuid = req.params[:uuid]
		object = self.datastore.fetch( uuid ) or
			finish_with HTTP::NOT_FOUND, "no such object"
		metadata = self.metastore.fetch( uuid )

		res = req.response
		res.body = object
		res.content_type = metadata['format']

		return res
	end


	# POST /
	# Upload a new object.
	post do |req|
		metadata = self.extract_default_metadata( req )

		uuid = self.datastore.save( req.body )
		self.metastore.save( uuid, metadata )

		url = req.base_uri.dup
		url.path += uuid

		res = req.response
		res.headers.location = url
		res.status = HTTP::CREATED

		res.for( :text, :json, :yaml ) { metadata }

		return res
	end


	# PUT /«uuid»
	# Replace the data associated with +uuid+.
	put ':uuid' do |req|
		metadata = self.extract_default_metadata( req )

		uuid = req.params[:uuid]
		object = self.datastore.fetch( uuid ) or
			finish_with HTTP::NOT_FOUND, "no such object"

		self.datastore.replace( uuid, req.body )
		self.metastore.merge( uuid, metadata )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	# DELETE /«uuid»
	# Remove the object associated with +uuid+.
	delete ':uuid' do |req|
		uuid = req.params[:uuid]

		self.datastore.remove( uuid ) or finish_with( HTTP::NOT_FOUND, "No such object." )
		metadata = self.metastore.remove( uuid )

		res = req.response
		res.status = HTTP::OK

		# TODO: Remove in favor of default metadata when the metastore
		# knows what that is.
		res.for( :text ) do
			"%d bytes for %s deleted." % [ metadata['extent'], uuid ]
		end
		res.for( :json, :yaml ) {{ uuid: uuid, extent: metadata['extent'] }}

		return res
	end


	#
	# Metastore routes
	#

	# GET /«uuid»/metadata
	# Fetch all metadata for «uuid».
	get ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { self.metastore.fetch( uuid ) }

		return res
	end


	# GET /«uuid»/metadata/«key»
	# Fetch metadata value associated with «key» for «uuid».
	get ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key  = req.params[:key]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { self.metastore.fetch( uuid, key ) }

		return res
	end


	# POST /«uuid»/metadata
	# Merge new metadata into the existing metadata for «uuid».
	post ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		new_metadata = self.extract_metadata( req )
		self.metastore.merge( uuid, new_metadata )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	#########
	protected
	#########

	### Return a Hash of default metadata extracted from the given +request+.
	def extract_default_metadata( request )
		return {
			'useragent'     => request.headers.user_agent,
			'extent'        => request.headers.content_length,
			'uploadaddress' => request.remote_ip,
			'format'        => request.content_type
		}
	end

	### Extract and validate supplied metadata from the +request+.
	def extract_metadata( req )
		new_metadata = req.params.fields.dup
		new_metadata.delete( :uuid )

		protected_keys = PROTECTED_METADATA_KEYS & new_metadata.keys

		unless protected_keys.empty?
			finish_with HTTP::FORBIDDEN,
				"Unable to alter protected metadata. (%s)" % [ protected_keys.join(', ') ]
		end

		return new_metadata
	end

end # class Thingfish

# vim: set nosta noet ts=4 sw=4:
