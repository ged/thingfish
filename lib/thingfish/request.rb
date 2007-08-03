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
#       if request.multipart?
#           files, params = request.parse_multipart
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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'forwardable'

### Resource wrapper class
class ThingFish::Request
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns
	
	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### A parsed Accept-header parameter
	class AcceptParam
		include ThingFish::Loggable, Comparable
		
		# The default quality value (weight) if none is specified
		Q_DEFAULT = 1.0
		Q_MAX = Q_DEFAULT

		
		### Parse the given +accept_param+ and return an AcceptParam object.
		def self::parse( accept_param )
			raise ArgumentError, "Bad Accept param: no media-range" unless
				accept_param =~ %r{/}
			media_range, *stuff = accept_param.split( /\s*;\s*/ )
			type, subtype = media_range.split( '/', 2 )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }
	
			return new( type, subtype, qval.first, *opts )
		end
		


		### Create a new ThingFish::Request::AcceptParam with the
		### given media +range+, quality value (+qval+), and extensions
		def initialize( type, subtype, qval=Q_DEFAULT, *extensions )
			type    = nil if type == '*'
			subtype = nil if subtype == '*'
			
			@type       = type
			@subtype    = subtype
			@qvalue     = normalize_qvalue( qval )
			@extensions = extensions.flatten
		end


		######
		public
		######

		# The 'type' part of the media range
		attr_reader :type

		# The 'subtype' part of the media range
		attr_reader :subtype

		# The weight of the param
		attr_reader :qvalue

		# An array of any accept-extensions specified with the parameter
		attr_reader :extensions


		### Return a human-readable version of the object
		def inspect
			"#<%s:0x%07x '%s/%s' q=%0.3f %p>" % [
				self.class.name,
				self.object_id * 2,
				self.type || '*',
				self.subtype || '*',
				self.qvalue,
				self.extensions,
			]
		end
		
		### Return the parameter as a String suitable for inclusion in an Accept 
		### HTTP header
		def to_s
			[
				self.mediatype,
				self.qvaluestring,
				self.extension_strings
			].compact.join(';')
		end


		### The mediatype of the parameter, consisting of the type and subtype
		### separated by '/'.
		def mediatype
			"%s/%s" % [ self.type || '*', self.subtype || '*' ]
		end
		alias_method :mimetype, :mediatype
		alias_method :content_type, :mediatype
		

		### The weighting or "qvalue" of the parameter in the form "q=<value>"
		def qvaluestring
			"q=%0.2f" % [self.qvalue]
		end
		
		
		### Return a String containing any extensions for this parameter, joined
		### with ';'
		def extension_strings
			return nil if @extensions.empty?
			@extensions.compact.join('; ')
		end


		### Comparable interface. Sort parameters by weight: Returns -1 if +other+ 
		### is less specific than the receiver, 0 if +other+ is as specific as 
		### the receiver, and +1 if +other+ is more specific than the receiver.
		def <=>( other )
			if @type.nil?
				return 1 if ! other.type.nil?
			elsif other.type.nil?
				return -1 
			end
			
			if @subtype.nil?
				return 1 if ! other.subtype.nil?
			elsif other.subtype.nil?
				return -1 
			end
			
			if rval = (other.extensions.length <=> @extensions.length).nonzero?
				return rval
			end
			
			if rval = (other.qvalue <=> @qvalue).nonzero?
				return rval
			end
			
			return 0
		end
		
		
		#######
		private
		#######

		### Given an input +qvalue+, return the Float equivalent.
		def normalize_qvalue( qvalue )
			return Q_DEFAULT unless qvalue
			qvalue = Float( qvalue.to_s.sub(/q=/, '') ) unless
				qvalue.is_a?( Float )

			if qvalue > Q_MAX
				self.log.warn "Squishing invalid qvalue %p to %0.1f" % 
					[ qvalue, Q_DEFAULT ]
				return Q_DEFAULT
			end
			
			return qvalue
		end
		
	end # ThingFish::Request::AcceptParam


	### Create a new ThingFish::Request wrapped around the given +mongrel_request+.
	def initialize( mongrel_request )
		@mongrel_request = mongrel_request
		@headers         = nil
		@accepted_types  = nil
	end


	######
	public
	######

	# Methods that fall through to the Mongrel request object
	def_delegators :@mongrel_request, :body, :params
	
	
	# The original Mongrel::HttpRequest object
	attr_reader :mongrel_request
	
	
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


	### Read in the Accept header and return an array of AcceptParam objects.
	def accepted_types
		@accepted_types ||= self.parse_accept_header( self.headers['Accept'] )
		return @accepted_types
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
		header.flatten.each do |headerval|
			params = headerval.split( /\s*,\s*/ )

			params.each do |param|
				rval << AcceptParam.parse( param )
			end
		end
		
		return rval
	end
	
	
	

end # ThingFish::Request

# vim: set nosta noet ts=4 sw=4:
