#!/usr/bin/ruby
#
# ThingFish HTTP Content-negotiation spike
# 
# Time-stamp: <24-Aug-2003 16:11:13 deveiant>
#

BEGIN {
	require 'pathname'
	
	base = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = base + 'lib'

	$LOAD_PATH.unshift libdir.to_s unless $LOAD_PATH.include?( libdir.to_s )

	require base + "utils.rb"
	include UtilityFunctions
}


# The problem:
#  (http://www.w3.org/Protocols/rfc2616/rfc2616-sec12.html)


#   Accept: text/html
#   Accept: application/x-yaml, application/json; q=0.9, text/xml; q=0.75
#   Accept: image/png, image/gif; q=0.75, image/*, */*

Q_DEFAULT = "1.0"
FILTERS = {
	:html	=> 'text/html',
	:yaml	=> 'application/x-yaml',
	:json	=> 'application/json',
	:rdf	=> 'text/xml+rdf',
}

class Negotiator

	class AcceptParam
		include Comparable
		def initialize( range='*/*', qval=Q_DEFAULT, *accept_exts )
			type, subtype = range.split( '/', 2 )
			type = nil if type == '*'
			subtype = nil if subtype == '*'
			qval ||= Q_DEFAULT
			
			@type = type
			@subtype = subtype
			@qvalue = Float( qval.sub(/q=/, '') )
			@accept_exts = accept_exts.flatten
		end

		attr_accessor :type, :subtype, :qvalue, :accept_exts

		def inspect
			"#<%s:0x%07x '%s/%s' q=%0.3f %p>" % [
				self.class.name,
				self.object_id * 2,
				self.type || '*',
				self.subtype || '*',
				self.qvalue,
				self.accept_exts,
			]
		end
		
		def <=>( other )
			if @type.nil?
				return 1 if ! other.type.nil?
			else
				return -1 if other.type.nil?
			end
			
			if @subtype.nil?
				return 1 if ! other.subtype.nil?
			else
				return -1 if other.subtype.nil?
			end
			
			if rval = (@accept_exts.length <=> other.accept_exts.length).nonzero?
				return rval
			end
			
			if rval = (@qvalue <=> other.qvalue).nonzero?
				return rval
			end
			
			return 0
		end
	end		

	def initialize( filters )
		@filters = filters
	end
	
	### Return a filter which will translate the given +content_type+ into one of
	### the types specified by +accept_header+, or nil if no suitable filter is found.
	def find_filter( content_type, accept_header )
		accepts = parse_accept_header( accept_header )
		
	end
	
	### Parse the given +header+ and return a list of mimetypes in order of 
	### specificity and q-value, with most-specific and highest q-values sorted
	### first.
	def parse_accept_header( header )
		rval = []
		
		# Accept         = "Accept" ":"
        #                 #( media-range [ accept-params ] )
        # 
		# media-range    = ( "*/*"
		#                  | ( type "/" "*" )
		#                  | ( type "/" subtype )
		#                  ) *( ";" parameter )
		# accept-params  = ";" "q" "=" qvalue *( accept-extension )
		# accept-extension = ";" token [ "=" ( token | quoted-string ) ]
		params = header.sub( /accept\s*:\s*/i, '' ).split( /\s*,\s*/ )

		params.each do |param|
			media_range, qvalue, *accept_ext = param.split( /\s*;\s*/ )
			rval << AcceptParam.new( media_range, qvalue, *accept_ext )
		end
		
		return rval	
	end
	
end


start_irb_session( binding() )