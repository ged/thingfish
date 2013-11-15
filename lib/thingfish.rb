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
	OPERATIONAL_METADATA_KEYS = %w[
		format
		extent
		created
		uploadaddress
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
	param :limit, :integer, "The maximum number of records to return."
	param :offset, :integer, "The offset into the result set to use as the first result."
	param :order, /^(?<fields>[[:word:]]+(?:,[[:word:]]+)*)/,
		"The name(s) of the fields to order results by."
	param :direction, /^(asc|desc)$/i, "The order direction (ascending or descending)"
	param :casefold, :boolean, "Whether or not to convert to lowercase before matching"


	#
	# Content negotiation
	#
	plugin :negotiation


	#
	# Filters
	#
	plugin :filters

	### Modify outgoing headers on all responses to include version info.
	###
	filter :response do |res|
		res.headers.x_thingfish = Thingfish.version_string( true )
	end


	#
	# Routing
	#
	plugin :routing
	router :exclusive

	# GET /serverinfo
	# Return various information about the handler configuration.
	get '/serverinfo' do |req|
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

	# GET /
	# Fetch a list of all objects
	get do |req|
		finish_with HTTP::BAD_REQUEST, req.params.error_messages.join(', ') unless req.params.okay?

		uuids = self.metastore.search( req.params.valid )
		self.log.debug "UUIDs are: %p" % [ uuids ]

		base_uri = req.base_uri
		list = uuids.collect do |uuid|
			uri = base_uri.dup
			uri.path += uuid

			metadata = self.metastore.fetch( uuid )
			metadata['uri'] = uri.to_s
			metadata['uuid'] = uuid

			metadata
		end

		res = req.response
		res.for( :json, :yaml ) { list }
		res.for( :text ) do
			list.collect {|entry| "%s [%s, %0.2fB]" % entry.values_at(:url, :format, :extent) }
		end

		return res
	end


	# GET /«uuid»
	# Fetch an object by ID
	get ':uuid' do |req|
		uuid = req.params[:uuid]
		object = self.datastore.fetch( uuid ) or
			finish_with HTTP::NOT_FOUND, "No such object."
		metadata = self.metastore.fetch( uuid )

		res = req.response
		res.body = object
		res.content_type = metadata['format']

		return res
	end


	# POST /
	# Upload a new object.
	post do |req|
		metadata = self.extract_header_metadata( req )
		metadata.merge!( self.extract_default_metadata(req) )

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
			finish_with HTTP::NOT_FOUND, "No such object."

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
		res.for( :json, :yaml ) { self.metastore.fetch_value( uuid, key ) }

		return res
	end


	# POST /«uuid»/metadata/«key»
	# Create a metadata value associated with «key» for «uuid».
	post ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key  = req.params[:key]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )
		finish_with( HTTP::CONFLICT, "Key already exists." ) unless
			self.metastore.fetch_value( uuid, key ).nil?

		self.metastore.merge( uuid, key => req.body.read )

		res = req.response
		res.headers.location = req.uri.to_s
		res.body = nil
		res.status = HTTP::CREATED

		return res
	end


	# PUT /«uuid»/metadata/«key»
	# Replace or create a metadata value associated with «key» for «uuid».
	put ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key  = req.params[:key]

		finish_with( HTTP::FORBIDDEN, "Protected metadata." ) if
			OPERATIONAL_METADATA_KEYS.include?( key )
		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )
		previous_value = self.metastore.fetch( uuid, key )

		self.metastore.merge( uuid, key => req.body.read )

		res = req.response
		res.body = nil

		if previous_value
			res.status = HTTP::NO_CONTENT
		else
			res.headers.location = req.uri.to_s
			res.status = HTTP::CREATED
		end

		return res
	end


	# PUT /«uuid»/metadata
	# Replace user metadata for «uuid».
	put ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		op_metadata = self.metastore.fetch( uuid, *OPERATIONAL_METADATA_KEYS )
		new_metadata = self.extract_metadata( req )
		self.metastore.save( uuid, new_metadata.merge(op_metadata) )

		res = req.response
		res.status = HTTP::NO_CONTENT

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


	# DELETE /«uuid»/metadata
	# Remove all (but operational) metadata associated with «uuid».
	delete ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		self.metastore.remove_except( uuid, *OPERATIONAL_METADATA_KEYS )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	# DELETE /«uuid»/metadata
	# Remove the metadata associated with «key» for the given «uuid».
	delete ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key = req.params[:key]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )
		finish_with( HTTP::FORBIDDEN, "Protected metadata." ) if
			OPERATIONAL_METADATA_KEYS.include?( key )

		self.metastore.remove( uuid, key )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	#########
	protected
	#########


	### Overridden from the base handler class to allow spooled uploads.
	def handle_async_upload_start( request )
		self.log.info "Starting asynchronous upload: %s" %
			[ request.headers.x_mongrel2_upload_start ]
	end


	### Return a Hash of default metadata extracted from the given +request+.
	def extract_default_metadata( request )
		return {
			'useragent'     => request.headers.user_agent,
			'extent'        => request.headers.content_length,
			'uploadaddress' => request.remote_ip,
			'format'        => request.content_type,
			'created'       => Time.now.getgm,
		}
	end


	### Extract and validate supplied metadata from the +request+.
	def extract_metadata( req )
		new_metadata = req.params.fields.dup
		new_metadata.delete( :uuid )

		protected_keys = OPERATIONAL_METADATA_KEYS & new_metadata.keys

		unless protected_keys.empty?
			finish_with HTTP::FORBIDDEN,
				"Unable to alter protected metadata. (%s)" % [ protected_keys.join(', ') ]
		end

		return new_metadata
	end


	### Extract metadata from X-ThingFish-* headers from the given +request+ and return
	### them as a Hash.
	def extract_header_metadata( request )
		self.log.debug "Extracting metadata from headers: %p" % [ request.headers ]
		metadata = {}
		request.headers.each do |header, value|
			name = header.downcase[ /^x_thingfish_(?<name>[[:alnum:]\-]+)$/i, :name ] or next
			self.log.debug "Found metadata header %p" % [ header ]
			metadata[ name ] = value
		end

		return metadata
	end

end # class Thingfish

# vim: set nosta noet ts=4 sw=4:
