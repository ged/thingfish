#!/usr/bin/ruby
# 
# ThingFish::Request -- a wrapper around a Mongrel::HttpRequest that unwraps headers
# and provides parsing for content-negotiation headers and multipart documents.
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
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
# 
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish'
require 'thingfish/acceptparam'
require 'thingfish/exceptions'
require 'thingfish/mixins'
require 'thingfish/multipartmimeparser'
require 'forwardable'
require 'ipaddr'

### Request wrapper class
class ThingFish::Request
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns
	
	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Pattern to match the contents of ETag and If-None-Match headers
	ENTITY_TAG_PATTERN = %r{
		(w/)?		# Weak flag
		"			# Opaque-tag
			([^"]+)	# Quoted-string
		"			# Closing quote
	  }ix


	### Create a new ThingFish::Request wrapped around the given +mongrel_request+.
	### The specified +spooldir+ will be used for spooling uploaded files, 
	def initialize( mongrel_request, config )
		@config          = config
		@headers         = nil
		@query_args		 = nil
		@accepted_types  = nil
		@uri             = nil
		@entity_bodies   = nil
		@form_metadata   = nil

		@mongrel_request = mongrel_request
		@metadata        = Hash.new {|h,k| h[k] = {} }
	end


	######
	public
	######

	# Methods that fall through to the Mongrel request object
	def_delegators :@mongrel_request, :body, :params
	
	
	# The original Mongrel::HttpRequest object
	attr_reader :mongrel_request

	# The hashes of uploaded metadata, one per body part being uploaded, keyed on the IO
	# of the uploaded file.
	attr_reader :metadata
	
	
	### Return a URI object for the requested URI.
	def uri
		if @uri.nil?
			params = @mongrel_request.params
			@uri = URI::HTTP.build(
				:scheme => 'http',
				:host   => params['SERVER_NAME'],
				:port   => params['SERVER_PORT'],
				:path   => params['REQUEST_PATH'],
				:query  => params['QUERY_STRING']
			)
		end

		return @uri
	end


	### Return the URI path with the parts leading up to the current handler.
	def path_info
		@mongrel_request.params['PATH_INFO']
	end
	
	
	### Return a Hash of the HTTP headers of the request. Note that the headers are
	### named with their original names, and *not* the transformed names that 
	### Mongrel's request object returns them as. Multiple headers with the same name
	### will be returned as a single Array with all the header values.
	def headers
		unless @headers
			tuples = @mongrel_request.params.
				find_all {|k,v| k =~ /^HTTP_/ }.
				collect {|k,v| [k.sub(/^HTTP_/, ''), v] }
			@headers = ThingFish::Table.new( tuples )
		end
		
		return @headers
	end
	alias_method :header, :headers


	### Return a Hash of request query arguments.  This is a regular Hash, rather
	### than a ThingFish::Table, because we can't arbitrarily normalize query
	### arguments.
	### ?arg1=yes&arg2=no&arg3  #=> {'arg1' => 'yes', 'arg2' => 'no', 'arg3' => nil}
	### TODO: Parse query args for methods other than GET.
	def query_args
		return {} if @uri.query.nil?
		@query_args ||= @uri.query.split(/[&;]/).inject({}) do |hash,arg|
			key, val = arg.split('=')
			case val
			when NilClass
				val = nil
			when /^\d+$/
				val = val.to_i
			else
				val = URI.decode( val )
			end

			hash[ URI.decode( key ) ] = val
			hash
		end
		self.log.debug( "Query arguments parsed as: %p" % [ @query_args ] )
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

	
	### Returns true if the request is of type 'multipart/form-request' and has
	### a valid boundary.
	def has_multipart_body?
		content_type = self.headers[:content_type] or return false
		return content_type =~ MULTIPART_MIMETYPE_PATTERN ? true : false
	end
	alias_method :is_multipart?, :has_multipart_body?


	### Get the body IO and the merged hash of metadata
	def get_body_and_metadata
		raise ArgumentError, "Can't return a single body for a multipart request" if
			self.has_multipart_body?
		
		default_metadata = {
			:useragent     => self.headers[ :user_agent ],
			:uploadaddress => self.remote_addr
		}

		extracted_metadata = self.metadata[ @mongrel_request.body ] || {}

		# Content metadata is determined from http headers
		merged = extracted_metadata.merge({
			:format => self.headers[ :content_type ],
			:extent => self.headers[ :content_length ],
		})
		merged.update( default_metadata )
		
		return @mongrel_request.body, merged
	end
	
	
	### Call the provided block once for each entity body of the request, which may
	### be multiple times in the case of a multipart request.
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
	def each_body  # :yields: body_io, metadata_hash
		default_metadata = {
			:useragent     => self.headers[ :user_agent ],
			:uploadaddress => self.remote_addr
		}

		# Parse the request's body parts if they aren't already
		unless @entity_bodies
			if self.has_multipart_body?
				@entity_bodies, @form_metadata = self.parse_multipart_body
			else
				body, metadata = self.get_body_and_metadata
				@entity_bodies = { body => metadata }
				@form_metadata = {}
			end

			self.log.debug "Parsed %d bodies and %d form_metadata (%p)" % 
				[@entity_bodies.length, @form_metadata.length, @form_metadata.keys]
		end

		# Yield the entity body and merged metadata for each part
		@entity_bodies.each do |body, body_metadata|
			extracted_metadata = self.metadata[body] || {}

			# Content metadata is determined per-multipart section
			merged = extracted_metadata.merge( @form_metadata )
			merged.update( body_metadata )
			merged.update( default_metadata )
			
			body.open if body.closed?
			self.log.debug "Yielding body = %p, merged metadata = %p" %
				[ body, merged ]
			yield( body, merged )
 		end
	end


	### Checks cache headers against the given etag and modification time.
	### Returns boolean true if the client claims to have a valid copy.
	def is_cached_by_client?( etag, modtime )
		modtime_checked = false
		self.log.debug "Checking to see if we can send a cached response"
		
		path_info = self.path_info
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
	
	
	### Returns the current request's http METHOD.
	def http_method
		return self.params['REQUEST_METHOD']
	end
	
	
	### Returns the requester IP address as an IPAddr object.
	def remote_addr
		return IPAddr.new( self.params['REMOTE_ADDR'] )
	end
	
	
	
	#########
	protected
	#########

	### Parse the files and form parameters from a multipart (upload) form request 
	### body. It throws ThingFish::RequestErrors on malformed input, or if you
	### try to parse a multipart body from a non-multipart request.
	def parse_multipart_body
		content_type = self.headers[ :content_type ] or
			raise ThingFish::RequestError, "No content-type header?!"

		# Match explicitly here instead of calling has_multipart_body? so
		# we aren't replying on $1 and $2 being set at a distance
		unless content_type =~ MULTIPART_MIMETYPE_PATTERN
			self.log.error "Tried to parse a multipart body for a '%s' request" %
				[content_type]
			raise ThingFish::RequestError, "not a multipart form request"
		end
		
		mimetype, boundary = $1, $2
		self.log.debug "Parsing a %s document with boundary %p" % [mimetype, boundary]
		
		parser = ThingFish::MultipartMimeParser.new( @config.spooldir, @config.bufsize )
		
		return parser.parse( @mongrel_request.body, boundary )
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
	
end # ThingFish::Request

# vim: set nosta noet ts=4 sw=4:
