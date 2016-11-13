# -*- ruby -*-
#encoding: utf-8

require 'strelka'
require 'strelka/app'

require 'configurability'
require 'loggability'

require 'thingfish' unless defined?( Thingfish )
require 'thingfish/processor'

#
# Network-accessable datastore service
#
class Thingfish::Handler < Strelka::App
	extend Loggability,
	       Configurability


	# Strelka App ID
	ID = 'thingfish'


	# Loggability API -- log to the :thingfish logger
	log_to :thingfish


	# Configurability API -- set config defaults
	CONFIG_DEFAULTS = {
		datastore: 'memory',
		metastore: 'memory',
		processors: [],
		event_socket_uri: 'tcp://127.0.0.1:3475',
	}

	# Metadata keys which aren't directly modifiable via the REST API
	# :TODO: Consider making either all of these or a subset of them
	#        be immutable.
	OPERATIONAL_METADATA_KEYS = %w[
		format
		extent
		created
		uploadaddress
	]

	# Metadata keys that must be provided by plugins for related resources
	REQUIRED_RELATED_METADATA_KEYS = %w[
		relationship
		format
	]


	require 'thingfish/mixins'
	require 'thingfish/datastore'
	require 'thingfish/metastore'
	extend Strelka::MethodUtilities


	##
	# Configurability API
	config_key :thingfish

	# The configured datastore type
	singleton_attr_accessor :datastore

	# The configured metastore type
	singleton_attr_accessor :metastore

	# The ZMQ socket for publishing various resource events.
	singleton_attr_accessor :event_socket_uri

	# The list of configured processors.
	singleton_attr_accessor :processors


	### Configurability API -- install the configuration
	def self::configure( config=nil )
		config = self.defaults.merge( config || {} )

		self.datastore        = config[:datastore]
		self.metastore        = config[:metastore]
		self.event_socket_uri = config[:event_socket_uri]

		self.processors = self.load_processors( config[:processors] )
		self.processors.each do |processor|
			self.filter( :request, &processor.method(:process_request) )
			self.filter( :response, &processor.method(:process_response) )
		end
	end


	### Load the Thingfish::Processors in the given +processor_list+ and return an instance
	### of each one.
	def self::load_processors( processor_list )
		self.log.info "Loading processors"
		processors = []

		processor_list.each do |processor_type|
			begin
				processors << Thingfish::Processor.create( processor_type )
				self.log.debug "  loaded %s: %p" % [ processor_type, processors.last ]
			rescue LoadError => err
				self.log.error "%p: %s while loading the %s processor" %
					[ err.class, err.message, processor_type ]
			end
		end

		return processors
	end


	### Set up the metastore, datastore, and event socket when the handler is
	### created.
	def initialize( * ) # :notnew:
		super

		@datastore = Thingfish::Datastore.create( self.class.datastore )
		@metastore = Thingfish::Metastore.create( self.class.metastore )
		@event_socket = nil
	end


	######
	public
	######

	# The datastore
	attr_reader :datastore

	# The metastore
	attr_reader :metastore

	# The PUB socket on which resource events are published
	attr_reader :event_socket


	### Run the handler -- overridden to set up the event socket on startup.
	def run
		self.setup_event_socket
		super
	end


	### Set up the event socket.
	def setup_event_socket
		if self.class.event_socket_uri && ! @event_socket
			@event_socket = Mongrel2.zmq_context.socket( :PUB )
			@event_socket.linger = 0
			@event_socket.bind( self.class.event_socket_uri )
		end
	end


	### Shutdown handler hook.
	def shutdown
		self.event_socket.close if self.event_socket
		super
	end


	### Restart handler hook.
	def restart
		if self.event_socket
			oldsock = @event_socket
			@event_socket = @event_socket.dup
			oldsock.close
		end

		super
	end


	########################################################################
	### P L U G I N S
	########################################################################

	#
	# Strelka plugin for Thingfish metadata
	#
	plugin :metadata


	#
	# Global params
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
	param :relationship, /^[\w\-]+$/, "The name of the relationship between two resources"


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

		self.check_resource_permissions( req )
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

		self.check_resource_permissions( req )

		uuids = self.metastore.search( req.params.valid )
		self.log.debug "UUIDs are: %p" % [ uuids ]

		base_uri = req.base_uri
		list = uuids.collect do |uuid|
			uri = base_uri.dup
			uri.path += '/' unless uri.path[-1] == '/'
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


	# GET /«uuid»/related
	# Fetch a list of all objects related to «uuid»
	get ':uuid/related' do |req|
		finish_with HTTP::BAD_REQUEST, req.params.error_messages.join(', ') unless req.params.okay?

		uuid = req.params[ :uuid ]
		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		uuids = self.metastore.fetch_related_oids( uuid )
		self.log.debug "Related UUIDs are: %p" % [ uuids ]

		base_uri = req.base_uri
		list = uuids.collect do |uuid|
			uri = base_uri.dup
			uri.path += '/' unless uri.path[-1] == '/'
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


	# GET /«uuid»/related/«relationship»
	# Get the data for the resource related to the one to the given +uuid+ via the
	# specified +relationship+.
	get ':uuid/related/:relationship' do |req|
		uuid = req.params[:uuid]
		rel = req.params[:relationship]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		criteria = {
			'relation' => uuid,
			'relationship' => rel,
		}
		uuid = self.metastore.search( criteria: criteria, include_related: true ).first or
			finish_with( HTTP::NOT_FOUND, "No such related resource." )

		object = self.datastore.fetch( uuid ) or
			raise "Metadata for non-existant resource %p" % [ uuid ]
		metadata = self.metastore.fetch( uuid )

		res = req.response
		res.body = object
		res.content_type = metadata['format']

		return res
	end


	# GET /«uuid»
	# Fetch an object by ID
	get ':uuid' do |req|
		uuid = req.params[:uuid]
		object = self.datastore.fetch( uuid )
		metadata = self.metastore.fetch( uuid )

		finish_with HTTP::NOT_FOUND, "No such object." unless object && metadata
		self.check_resource_permissions( req, nil, metadata )

		res = req.response
		res.content_type = metadata['format']

		self.add_etag_headers( req, metadata )

		if object.respond_to?( :path )
			path = Pathname( object.path )
			chroot_path = path.relative_path_from( req.server_chroot )
			res.extend_reply_with( :sendfile )
			res.headers.content_length = object.size
			res.extended_reply_data << File::SEPARATOR + chroot_path.to_s
		else
			res.body = object
		end

		return res
	end


	# POST /
	# Upload a new object.
	post do |req|
		uuid, metadata = self.save_resource( req )
		self.send_event( :created, :uuid => uuid )

		uri = req.base_uri.dup
		uri.path += '/' unless uri.path[-1] == '/'
		uri.path += uuid

		res = req.response
		res.headers.location = uri
		res.headers.x_thingfish_uuid = uuid
		res.status = HTTP::CREATED

		res.for( :text, :json, :yaml ) { metadata }

		return res
	end


	# PUT /«uuid»
	# Replace the data associated with +uuid+.
	put ':uuid' do |req|
		uuid = req.params[:uuid]
		self.datastore.include?( uuid ) or
			finish_with HTTP::NOT_FOUND, "No such object."

		self.check_resource_permissions( req, uuid )
		self.remove_related_resources( uuid )
		self.save_resource( req, uuid )
		self.send_event( :replaced, :uuid => uuid )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	# DELETE /«uuid»
	# Remove the object associated with +uuid+.
	delete ':uuid' do |req|
		uuid = req.params[:uuid]

		self.check_resource_permissions( req, uuid )

		self.datastore.remove( uuid ) or finish_with( HTTP::NOT_FOUND, "No such object." )
		metadata = self.metastore.remove( uuid )
		self.remove_related_resources( uuid )
		self.send_event( :deleted, :uuid => uuid )

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

		metadata = self.normalized_metadata_for( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { metadata }

		return res
	end


	# GET /«uuid»/metadata/«key»
	# Fetch metadata value associated with «key» for «uuid».
	get ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key  = req.params[:key]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { metadata[key] }

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

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		self.metastore.merge( uuid, key => req.body.read )
		self.send_event( :metadata_updated, :uuid => uuid, :key => key )

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

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		self.metastore.merge( uuid, key => req.body.read )
		self.send_event( :metadata_replaced, :uuid => uuid, :key => key )

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

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		op_metadata  = self.metastore.fetch( uuid, *OPERATIONAL_METADATA_KEYS )
		new_metadata = self.extract_metadata( req )
		self.metastore.transaction do
			self.metastore.remove_except( uuid, *OPERATIONAL_METADATA_KEYS )
			self.metastore.merge( uuid, new_metadata.merge(op_metadata) )
		end
		self.send_event( :metadata_replaced, :uuid => uuid )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { self.normalized_metadata_for(uuid) }

		return res
	end


	# POST /«uuid»/metadata
	# Merge new metadata into the existing metadata for «uuid».
	post ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		new_metadata = self.extract_metadata( req )
		self.metastore.merge( uuid, new_metadata )
		self.send_event( :metadata_updated, :uuid => uuid )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { self.normalized_metadata_for(uuid) }

		return res
	end


	# DELETE /«uuid»/metadata
	# Remove all (but operational) metadata associated with «uuid».
	delete ':uuid/metadata' do |req|
		uuid = req.params[:uuid]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		self.metastore.remove_except( uuid, *OPERATIONAL_METADATA_KEYS )
		self.send_event( :metadata_deleted, :uuid => uuid )

		res = req.response
		res.status = HTTP::OK
		res.for( :json, :yaml ) { self.normalized_metadata_for(uuid) }

		return res
	end


	# DELETE /«uuid»/metadata/«key»
	# Remove the metadata associated with «key» for the given «uuid».
	delete ':uuid/metadata/:key' do |req|
		uuid = req.params[:uuid]
		key = req.params[:key]

		finish_with( HTTP::NOT_FOUND, "No such object." ) unless self.metastore.include?( uuid )
		finish_with( HTTP::FORBIDDEN, "Protected metadata." ) if
			OPERATIONAL_METADATA_KEYS.include?( key )

		metadata = self.metastore.fetch( uuid )
		self.check_resource_permissions( req, uuid, metadata )

		self.metastore.remove( uuid, key )
		self.send_event( :metadata_deleted, :uuid => uuid, :key => key )

		res = req.response
		res.status = HTTP::NO_CONTENT

		return res
	end


	#########
	protected
	#########


	### Save the resource in the given +request+'s body and any associated metadata
	### or additional resources.
	def save_resource( request, uuid=nil )
		metadata = request.metadata
		metadata.merge!( self.extract_header_metadata(request) )
		metadata.merge!( self.extract_default_metadata(request) )

		self.check_resource_permissions( request, uuid, metadata )
		self.verify_operational_metadata( metadata )

		if uuid
			self.log.info "Replacing resource %s (encoding: %p)" %
				[ uuid, request.headers.content_encoding ]
			self.datastore.replace( uuid, request.body )
			self.metastore.merge( uuid, metadata )
		else
			self.log.info "Saving new resource (encoding: %p)." %
				[ request.headers.content_encoding ]
			uuid = self.datastore.save( request.body )
			self.metastore.save( uuid, metadata )
		end

		self.save_related_resources( request, uuid )

		return uuid, metadata
	end


	### Save any related resources in the given +request+ with a relationship to the
	### resource with the given +uuid+.
	def save_related_resources( request, uuid )
		request.related_resources.each do |io, metadata|
			self.log.debug "Saving a resource related to %s: %p" % [ uuid, metadata ]
			next unless self.check_related_metadata( metadata )

			self.log.debug "  related metadata checks passed; storing it."
			metadata = self.extract_connection_metadata( request ).merge( metadata )
			self.log.debug "  metadata is: %p" % [ metadata ]
			r_uuid = self.datastore.save( io )
			metadata['created']  = Time.now.getgm
			metadata['relation'] = uuid

			self.metastore.save( r_uuid, metadata )
			self.log.debug "  %s for %s saved as %s" %
				[ metadata['relationship'], uuid, r_uuid ]
		end
	end


	### Remove any resources that are related to the one with the specified +uuid+.
	def remove_related_resources( uuid )
		self.metastore.fetch_related_oids( uuid ).each do |r_uuid|
			self.datastore.remove( r_uuid )
			self.metastore.remove( r_uuid )
			self.log.info "Removed related resource %s for %s." % [ r_uuid, uuid ]
		end
	end


	### Do some consistency checks on the given +metadata+ for a related resource,
	### returning +true+ if it meets the requirements.
	def check_related_metadata( metadata )
		REQUIRED_RELATED_METADATA_KEYS.each do |attribute|
			unless metadata[ attribute ]
				self.log.error "Metadata for required resource must include '#{attribute}' attribute!"
				return false
			end
		end
		return true
	end


	### Overridden from the base handler class to allow spooled uploads.
	def handle_async_upload_start( request )
		self.log.info "Starting asynchronous upload: %s" %
			[ request.headers.x_mongrel2_upload_start ]
		return nil
	end


	### Return a Hash of default metadata extracted from the given +request+.
	def extract_default_metadata( request )
		return self.extract_connection_metadata( request ).merge(
			'extent'        => request.headers.content_length,
			'format'        => request.content_type,
			'created'       => Time.now.getgm
		)
	end


	### Return a Hash of metadata extracted from the connection information
	### of the given +request+.
	def extract_connection_metadata( request )
		return {
			'useragent'     => request.headers.user_agent,
			'uploadaddress' => request.remote_ip,
		}
	end


	### Extract and validate supplied metadata from the +request+.
	def extract_metadata( req )
		new_metadata = req.params.fields.dup
		new_metadata = self.remove_operational_metadata( new_metadata )
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


	### Fetch the current metadata for +uuid+, altering it for easier
	### round trips with REST.
	def normalized_metadata_for( uuid )
		return self.metastore.fetch(uuid).merge( 'uuid' => uuid )
	end


	### Check that the metadata provided contains valid values for
	### the operational keys, before saving a resource to disk.
	def verify_operational_metadata( metadata )
		if metadata.values_at( *OPERATIONAL_METADATA_KEYS ).any?( &:nil? )
			finish_with( HTTP::BAD_REQUEST, "Missing operational attribute." )
		end
	end


	### Prune operational +metadata+ from the provided hash.
	def remove_operational_metadata( metadata )
		operationals = OPERATIONAL_METADATA_KEYS + [ 'uuid' ]
		return metadata.reject{|key, _| operationals.include?(key) }
	end


	### Send an event of +type+ with the given +msg+ over the zmq event socket.
	def send_event( type, msg )
		esock = self.event_socket or return
		self.log.debug "Publishing %p event: %p" % [ type, msg ]
		esock.sendm( type.to_s )
		esock.send( Yajl.dump(msg) )
	end


	### Add browser cache headers for resources.  This requires the sha256
	### processor plugin to be enabled for stored resources.
	def add_etag_headers( request, metadata )
		response = request.response
		checksum = metadata[ 'checksum' ]
		return unless checksum

		if (( match = request.headers[ :if_none_match ] ))
			match = match.gsub( '"', '' ).split( /,\s*/ )
			finish_with( HTTP::NOT_MODIFIED ) if match.include?( checksum )
		end

		response.headers[ :etag ] = checksum
		return
	end


	### Supply a method that child handlers can override.  The regular auth
	### plugin runs too early (but can also be used), this hook allows
	### child handlers to make access decisions based on the +request+
	### object, +uuid+ of the resource, or +metadata+ of the fetched resource.
	def check_resource_permissions( request, uuid=nil, metadata=nil ); end


end # class Thingfish::Handler

# vim: set nosta noet ts=4 sw=4:
