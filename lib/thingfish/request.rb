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


	### Create a new ThingFish::Request wrapped around the given +mongrel_request+.
	### The specified +spooldir+ will be used for spooling uploaded files, 
	def initialize( mongrel_request, config )
		@mongrel_request = mongrel_request
		@config          = config
		@headers         = nil
		@query_args		 = nil
		@accepted_types  = nil
		@uri             = nil
	end


	######
	public
	######

	# Methods that fall through to the Mongrel request object
	def_delegators :@mongrel_request, :body, :params
	
	
	# The original Mongrel::HttpRequest object
	attr_reader :mongrel_request
	
	
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


	### Return a Hash of request query arguments.  This is a regular Hash, rather
	### than a ThingFish::Table, because we can't arbitrarily normalize query
	### arguments.
	### ?arg1=yes&arg2=no&arg3  #=> {'arg1' => 'yes', 'arg2' => 'no', 'arg3' => true}
	### TODO: Parse query args for methods other than GET.
	def query_args
		return {} if @uri.query.nil?
		@query_args = @uri.query.split(/[&;]/).inject({}) do |hash,arg|
			key, val = arg.split('=')
			case val
			when NilClass
				val = true
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
