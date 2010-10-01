#!/usr/bin/env ruby

require 'uri'
require 'forwardable'
require 'ipaddr'
require 'tempfile'
require 'strscan'

require 'thingfish'
require 'thingfish/acceptparam'
require 'thingfish/exceptions'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/multipartmimeparser'

# ThingFish::Request -- an HTTP request object class. It provides request-parsing,
# content-negotiation, and handling of multipart body entities.
#
# == Synopsis
#
#   require 'thingfish/request'
#
#   def process( request, response )
#       if request.has_multipart_body?
#           files, params = request.parse_multipart_body
#       end
#
#       types = request.accepted_types
#       languages = request.accepted_languages
#       encodings = request.accepted_encodings
#       charsets = request.accepted_charsets
#   end
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
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::Request
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns,
			ThingFish::HtmlInspectableObject

	extend Forwardable

	# Pattern to match the contents of ETag and If-None-Match headers
	ENTITY_TAG_PATTERN = %r{
		(w/)?		# Weak flag
		"			# Opaque-tag
			([^"]+)	# Quoted-string
		"			# Closing quote
	  }ix

    # Separators     = "(" | ")" | "<" | ">" | "@"
    #                | "," | ";" | ":" | "\" | <">
    #                | "/" | "[" | "]" | "?" | "="
    #                | "{" | "}" | SP | HT
	SEPARATORS = Regexp.quote("(\")<>@,;:\\/[]?={} \t")

	# token          = 1*<any CHAR except CTLs or separators>
	TOKEN = /[^#{SEPARATORS}[:cntrl:]]+/

	# Borrow URI's pattern for matching absolute URIs
	REQUEST_URI = URI::REL_URI_REF

	# Canonical HTTP methods
	REQUEST_METHOD = /OPTIONS|GET|HEAD|POST|PUT|DELETE|TRACE|CONNECT/

	# Extension HTTP methods
	# extension-method = token
	EXTENSION_METHOD = TOKEN

	# Explicit space
	SP = /[ ]/

	# HTTP-Version   = "HTTP" "/" 1*DIGIT "." 1*DIGIT
	HTTP_VERSION = %r{HTTP/(\d+\.\d+)}

	# Pattern to match the request line:
	#   Request-Line   = Method SP Request-URI SP HTTP-Version CRLF
	#   GET /blah HTTP/1.1
	REQUEST_LINE = %r{
		^
		(								
			#{REQUEST_METHOD}
			|
			#{EXTENSION_METHOD}
		)								# Method: $1
		#{SP}
		(#{REQUEST_URI})				# URI: $2 (+ 3-10 from the URI regex)
		#{SP}
		#{HTTP_VERSION}					# HTTP version: $11 (from the contained constant)
		#{CRLF_REGEXP}
	}x

	# LWS            = [CRLF] 1*( SP | HT )
	LWS = /#{CRLF_REGEXP}[ \t]+/

    # TEXT           = <any OCTET except CTLs, but including LWS>
	TEXT = /[^[:cntrl:]]|\t/

    # message-header = field-name ":" [ field-value ]
    # field-name     = token
    # field-value    = *( field-content | LWS )
    # field-content  = <the OCTETs making up the field-value
    #                  and consisting of either *TEXT or combinations
    #                  of token, separators, and quoted-string>

	# Pattern to match a single header tuple, possibly split over multiple lines
	HEADER_LINE = %r{
		^
		(#{TOKEN})				# Header key: $1
		:
		((?:#{LWS}|#{TEXT})*)	# Header value: $2
		#{CRLF_REGEXP}
	}mx


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Parse a ThingFish::Request object from the specified +data+.
	def self::parse( data, config, socket )
		ThingFish.logger.debug "Parsing request from data: %p" % [ data ]
		scanner = StringScanner.new( data )

		# Parse the request line
		scanner.scan( REQUEST_LINE ) or
			raise ThingFish::RequestError, "malformed request: expected request-line"
		http_method, uristring, version = scanner[1], scanner[2], scanner[11]
		uri = URI.parse( uristring )

		ThingFish.logger.debug "Parsed request: %p, %p, %p" % [ http_method, uristring, version ]

		# Parse each header, building up a Table
		headers = ThingFish::Table.new
		while scanner.scan( HEADER_LINE )
			key, val = scanner[1], scanner[2]

			headers.append( key => val.strip.gsub( /#{CRLF}\s+/, ' ') )
		end

		# All the header data should be consumed up to the blank line -- it's an error
		# if not
		unless scanner.rest == CRLF
			ThingFish.logger.error "extra stuff after headers: %p" % [ scanner.rest ]
			raise ThingFish::RequestError, "malformed request: extra stuff after headers?!"
		end

		return new( socket, http_method, uri, version, headers, config )
	end



	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ThingFish::Request wrapped around the given +client+.
	### The specified +config+ is used to determine paths to the data directory, spool
	### directory, and other configurable things.
	def initialize( socket, http_method, uri, http_version, headers, config )
		uri = URI.parse( uri ) unless uri.is_a?( URI )
		uri.freeze
		uri.path.freeze

		@socket         = socket
		@http_method    = http_method.to_sym
		@http_version   = Float( http_version )
		@uri            = uri
		@config         = config
		@headers        = headers

		@query_args     = nil
		@accepted_types = nil
		@entity_bodies  = nil
		@form_metadata  = nil
		@body           = nil
		@profile        = false
		@authed_user    = nil

		@spooldir          = @config.spooldir_path
		@related_resources = Hash.new {|h,k| h[k] = {} }
		@metadata          = Hash.new {|h,k| h[k] = {} }

		# Check for the presence of the profile key.
		if self.uri.query and self.uri.query.gsub!( /[&;]?(#{PROFILING_ARG}=?[^&;]*)/, '' )
			profile_arg = $1
			@profile = ( profile_arg =~ /=(?:1|yes|true)$/i ? true : false )
		end
	end


	######
	public
	######

	# Methods that get delegated to the request URI
	def_delegators :@uri, :path

	# The HTTP method of the request (as a Symbol)
	attr_reader :http_method

	# The HTTP version of the request (as a Float)
	attr_reader :http_version

	# The URI of the request
	attr_reader :uri

	# The hashes of uploaded metadata, one per body part being uploaded, keyed on the IO
	# of the uploaded file.
	attr_reader :metadata

	# The entity body of the request (an IOish object)
	attr_accessor :body

	# A hash of resources related to the ones in the request, such as previews or thumbnails
	# generated by filters. The keys of the hash are body IO objects, and the values are
	# contained in a hash of the form:
	# {
	#    <related IO> => { <related metadata> }
	# }
	attr_reader :related_resources

	# The name of the authenticated user
	attr_accessor :authed_user
	alias_method :authenticated_user, :authed_user
	alias_method :remote_user, :authed_user

	# The ThingFish::Table of request headers
	attr_accessor :headers
	alias_method :header, :headers


	### Return the URI path with the parts leading up to the current handler.
	def path_info
		raise NotImplementedError, "dunno how to do this yet"
	end


	### Returns a boolean based on the presence of a '_profile' query arg.
	def run_profile?
		return @profile
	end


	### Return a Hash of request query arguments.  This is a regular Hash, rather
	### than a ThingFish::Table, because we can't arbitrarily normalize query
	### arguments.
	### ?arg1=yes&arg2=no&arg3  #=> {'arg1' => 'yes', 'arg2' => 'no', 'arg3' => nil}
	def query_args
		return {} if self.uri.query.nil?
		@query_args ||= self.uri.query.split(/[&;]/).inject({}) do |hash,arg|
			key, val = arg.split('=')
			key = URI.decode( key )

			# Decode values
			val = URI.decode( val ) if val

			# If there's already a value in the Hash, turn it into an array if
			# it's not already, and append the new value
			if hash.key?( key )
				hash[ key ] = [ hash[key] ] unless hash[ key ].is_a?( Array )
				hash[ key ] << val
			else
				hash[ key ] = val
			end

			hash
		end

		self.log.debug "Query arguments parsed as: %p" % [ @query_args ]
		return @query_args
	end


	### Read in the Accept header and return an array of AcceptParam objects.
	def accepted_types
		@accepted_types ||= self.parse_accept_header( self.headers[:accept] )
		return @accepted_types
	end


	### Returns boolean true/false if the requestor can handle the given
	### +content_type+.
	def accepts?( content_type )
		return self.accepted_types.find {|type| type =~ content_type } ? true : false
	end
	alias_method :accept?, :accepts?


	### Returns boolean true/false if the requestor can handle the given
	### +content_type+, not including mime wildcards.
	def explicitly_accepts?( content_type )
		self.accepted_types.reject {|param| param.subtype.nil? }.
			find {|type| type =~ content_type } ? true : false
	end
	alias_method :explicitly_accept?, :explicitly_accepts?


	### Returns true if the request is of type 'multipart/form-request' and has
	### a valid boundary.
	def has_multipart_body?
		return false unless self.content_type
		return self.content_type =~ MULTIPART_MIMETYPE_PATTERN ? true : false
	end
	alias_method :is_multipart?, :has_multipart_body?


	### Attach additional resources and metadata information to the primary
	### resource body; these will be stored with `related_to` metadata pointing
	### to the original.
	###
	### +resource+::
	###    The uploaded (primary) resource body
	### +related_resource+::
	###    The new resource body as an IO-like object
	### +related_metadata+::
	###    The metadata to attach to the new resource, as a Hash.
	def append_related_resource( resource, related_resource, related_metadata={} )
		self.log.debug "Appending related resource %p (%p) to the list for %p" %
			[ related_resource, related_metadata, resource ]

		unless self.entity_bodies.key?( resource ) || self.related_resources.key?( resource )
			errmsg = "Cannot append %p related to %p: it is not a part of the request" % [
				related_resource,
				resource,
			]
			self.log.error( errmsg )
			raise ThingFish::ResourceError, errmsg
		end

		related_metadata[:relation] ||= 'appended'
		self.related_resources[ resource ][ related_resource ] = related_metadata

		# Add the related_resource as a key so future checks are aware that
		# it is part of this request
		self.related_resources[ related_resource ] = {}
	end


	### Append the specified additional +metadata+ for the given +resource+, which should be one
	### of the entity bodies yielded by #each_body
	def append_metadata_for( resource, metadata )

		unless @entity_bodies.key?( resource ) || @related_resources.key?( resource )
			errmsg = "Cannot append metadata related to %p: it is not a part of the request" % [
				resource,
			]
			self.log.error( errmsg )
			raise ThingFish::ResourceError, errmsg
		end

		self.log.debug "Appending metadata %p for resource %p" % [ metadata, resource ]
		self.metadata[ resource ].merge!( metadata )
	end


	### Call the provided block once for each entity body of the request, which may
	### be multiple times in the case of a multipart request. If +include_appended+
	### is +true+, any resources which have been appended will be yielded immediately after the
	### body to which they are related. Note that this applies even in the current loop -- the
	### block will get resources that have been appended from the previous block -- so care must
	### be taken to avoid recursing infinitely if you append resources which you can later consume.
	###
	### The +metadata_hash+ passed to the block of #each_body is a merged collection
	### of:
	###
	###  * Any metadata extracted by (previous) filters
	###  * Metadata passed in the request as query arguments (e.g., from an upload form)
	###  * Content metadata that pertains to the body being yielded
	###  * Request metadata (e.g., user agent, requester's IP, etc.)
	###
	### The hash is merged top-down, which means that later values supercede earlier
	### ones. This is to prevent free-form upload metadata from colliding with the
	### metadata required for the filestore and metastore themselves.
	def each_body( include_appended=false, &block )  # :yields: body_io, metadata_hash
		self.yield_each_resource( self.entity_bodies, include_appended, &block )
	end


	### Fetch a flat hash of the entity bodies for the request. If +include_appended+ is +true+,
	### include any appended related resources.
	def bodies( include_appended=false )
		rval = {}

		self.each_body( include_appended ) do |body, metadata|
			rval[body] = metadata
		end

		return rval
	end


	### Check the body IO objects to ensure they're still open.
	def check_body_ios
		self.each_body( true ) do |body,_|
			next unless body.respond_to?( :closed? )

			if body.closed?
				self.log.warn "Body IO unexpectedly closed -- reopening a new handle"

				# Create a new IO based on what the original type was
				clone = nil
				if body.is_a?( StringIO )
					clone = StringIO.new( body.string )
				else
					clone = File.open( body.path, 'r' )
				end

				# Retain the original IO's file and appended metadata
				@entity_bodies[ clone ] = @entity_bodies.delete( body ) if @entity_bodies.key?( body )
				@metadata[ clone ] = @metadata.delete( body ) if @metadata.key?( body )

				# Splice in the cloned IO into both keys and values of the related resources
				# tree
				@related_resources[ clone ] = @related_resources.delete( body ) if @related_resources.key?( body )
				@related_resources.each do |_,hash|
					hash[ clone ] = hash.delete( body ) if hash.key?( body )
				end

				self.log.debug "Body %p (%d) replaced with %p (%d)" %
					[ body, body.object_id, clone, clone.object_id ]
			else
				body.rewind
			end
		end
	end


	### Checks cache headers against the given etag and modification time.
	### Returns boolean true if the client claims to have a valid copy.
	def is_cached_by_client?( etag, modtime )
		modtime_checked = false
		self.log.debug "Checking to see if we can send a cached response"

		path_info = self.uri.path
		modtime = Time.parse( modtime.to_s ) unless modtime.is_a?( Time )

		# Check If-Modified-Since header
		if (( modtimestr = self.headers[:if_modified_since] ))
			client_modtime = Time.parse( modtimestr )
			self.log.debug "Comparing %s's modification dates (%p vs. %p)" %
				[ path_info, modtime, client_modtime ]

			return true if modtime <= client_modtime
			modtime_checked = true
		end

		# Check If-None-Match header
		if (( etagheader = self.headers[:if_none_match] ))
			self.log.debug "Testing etag %s on %s against resource's etag %s" %
				[ etagheader, path_info, etag ]

				# etag wildcard regexp
			if etagheader =~ /^\s*['"]?\*['"]?\s*$/

				# If we've already checked the modification data and our copy is newer
				# RFC 2616 14.26: "[...] if "*" is given and any current entity exists
				# for that resource, then the server MUST NOT perform the requested
				# method, unless required to do so because the resource's modification
				# date fails to match that supplied in an If-Modified-Since header
				# field in the request"
				if modtime_checked
					self.log.debug( ("Cache miss (%s): wildcard If-None-Match, but " +
						"If-Modified-Since is out of date") % [ path_info ] )
					return false
				end

				self.log.debug "Cache hit (%s): wildcard If-None-Match" %
					[ path_info ]
				return true
			end

			etagheader.scan( ENTITY_TAG_PATTERN ) do |weakflag, tag|
				if weakflag
					self.log.debug "Cache miss (%s): Weak entity tag" % [ path_info ]
					next
				end

				if tag == etag
					self.log.debug "Cache hit (%s)" % [ path_info ]
					return true
				else
					self.log.debug "Cache miss (%s)" % [ path_info ]
				end
			end
		end

		self.log.debug "Response for %s wasn't cacheable" % [ path_info ]
		return false
	end


	### Return +true+ if the request is from XMLHttpRequest (as indicated by the
	### 'X-Requested-With' header from Scriptaculous or jQuery)
	def is_ajax_request?
		xrw_header = self.headers[ :x_requested_with ]
		return true if !xrw_header.nil? && xrw_header =~ /xmlhttprequest/i
		return false
	end
	alias_method :ajax_request?, :is_ajax_request?


	### Return +true+ if the request has a 'Connection' header, and it is set to 'keep-alive'.
	def keepalive?
		keepalive_header = self.headers[ :connection ]
		return true if !keepalive_header.nil? && 
			keepalive_header =~ /keep-alive/i &&
			self.http_version >= 1.1
		return false
	end


	### Return the path portion of the request's URI
	def path
		return self.uri.path
	end


	### Returns the requester IP address as an IPAddr object.
	def remote_addr
		return IPAddr.new( @socket.peeraddr[3] )
	end


	### Returns the current request's Content-Type, or the DEFAULT_CONTENT_TYPE if
	### the header isn't set.
	def content_type
		return self.headers[ :content_type ] || DEFAULT_CONTENT_TYPE
	end


	### Sets the current request's Content-Type.
	def content_type=( type )
		return self.headers[ :content_type ] = type
	end


	#########
	protected
	#########

	### For each resource => metadata pair returned by the current +iterator+, merge the
	### toplevel metadata with the resource-specific metadata and pass both to the
	### block.
	def yield_each_resource( resources, include_appended, &block )
		immutable_metadata = self.get_immutable_metadata

		# Call the block for every resource
		resources.keys.each do |body|
			next if body.nil?

			body_metadata = resources[ body ]
			appended = self.related_resources[ body ].dup if self.related_resources.key?( body )

			body_metadata[ :format ] ||= DEFAULT_CONTENT_TYPE
			extracted_metadata = self.metadata[body] || {}

			# Content metadata is determined per-multipart section
			merged = extracted_metadata.merge( @form_metadata )
			merged.update( body_metadata )
			merged.update( immutable_metadata )

			block.call( body, merged )

			# Recurse if the appended resources should be included
			if appended && !appended.empty? && include_appended
				self.yield_each_resource( appended, true, &block )
			end
		end
	end


	### Returns the entity bodies of the request along with any related metadata as
	### a Hash:
	### {
	###    <body io> => { <body metadata> },
	###    ...
	### }
	def entity_bodies
		# Parse the request's body parts if they aren't already
		unless @entity_bodies
			if self.has_multipart_body?
				self.log.debug "Parsing multiple entity bodies."
				@entity_bodies, @form_metadata = self.parse_multipart_body
				self.log.debug "Got bodies = %p, form_metadata = %p" %
					[ @entity_bodies, @form_metadata ]
			else
				self.log.debug "Parsing single entity body (%p)." % [ self.body ]
				body, metadata = self.parse_singlepart_body

				@entity_bodies = { body => metadata }
				@form_metadata = {}
			end

			self.log.debug "Parsed %d bodies and %d form_metadata (%p)" %
				[@entity_bodies.length, @form_metadata.length, @form_metadata.keys]
		end

		return @entity_bodies
	end


	### Get the body IO and the initial metadata from a non-multipart request
	def parse_singlepart_body
		raise ArgumentError, "Can't return a single body for a multipart request" if
			self.has_multipart_body?

		metadata = {
			:useragent     => self.headers[ :user_agent ],
			:extent        => self.headers[ :content_length ],
			:uploadaddress => self.remote_addr,
			:format        => self.content_type
		}

		self.log.debug "Extracted metadata is: %p" % [ metadata ]

		# Read title out of the content-disposition
		if self.headers[:content_disposition] &&
			self.headers[:content_disposition] =~ /filename="(?:.*\\)?(.+?)"/i
			metadata[ :title ] = $1
		end

		return self.body, metadata
	end


	### Parse the files and form parameters from a multipart (upload) form request
	### body. It throws ThingFish::RequestErrors on malformed input, or if you
	### try to parse a multipart body from a non-multipart request.
	def parse_multipart_body
		raise ThingFish::RequestError, "No content-type header?!" unless self.content_type

		# Match explicitly here instead of calling has_multipart_body? so
		# we aren't replying on $1 and $2 being set at a distance
		unless self.content_type =~ MULTIPART_MIMETYPE_PATTERN
			self.log.error "Tried to parse a multipart body for a '%s' request" %
				[ self.content_type ]
			raise ThingFish::RequestError, "not a multipart form request"
		end

		mimetype, boundary = $1, $2
		self.log.debug "Parsing a %s document with boundary %p" % [mimetype, boundary]
		parser = ThingFish::MultipartMimeParser.new( @config.spooldir_path, @config.bufsize )

		self.log.debug "Parsing multipart data: %p" % [ self.body ]
		return parser.parse( self.body, boundary )
	end


	### Parse the given +header+ and return a list of mimetypes in order of
	### specificity and q-value, with most-specific and highest q-values sorted
	### first.
	def parse_accept_header( header )
		rval = []

		# Handle the case where there's more than one 'Accept:' header by
		# forcing everything to an Array
		header = [header] unless header.is_a?( Array )

		# Accept         = "Accept" ":"
		#                 #( media-range [ accept-params ] )
		#
		# media-range    = ( "*/*"
		#                  | ( type "/" "*" )
		#                  | ( type "/" subtype )
		#                  ) *( ";" parameter )
		# accept-params  = ";" "q" "=" qvalue *( accept-extension )
		# accept-extension = ";" token [ "=" ( token | quoted-string ) ]
		header.compact.flatten.each do |headerval|
			params = headerval.split( /\s*,\s*/ )

			params.each do |param|
				rval << ThingFish::AcceptParam.parse( param )
			end
		end

		rval << ThingFish::AcceptParam.new( '*', '*' ) if rval.empty?
		return rval
	end


	### Returns a frozen Hash of metadata belonging to the request that should not be allowed to
	### replaced by form values or extracted metadata.
	def get_immutable_metadata
		hash = {
			:useragent     => self.headers.user_agent,
			:uploadaddress => self.remote_addr,
		  }
		hash.freeze

		return hash
	end

end # ThingFish::Request

# vim: set nosta noet ts=4 sw=4:
