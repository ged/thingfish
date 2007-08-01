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
		
		
		def to_s
			[
				self.mediatype,
				self.qvaluestring,
				self.extension_strings
			].compact.join(';')
		end
		
		def mediatype
			"%s/%s" % [ self.type || '*', self.subtype || '*' ]
		end
		
		def qvaluestring
			"q=%0.2f" % [self.qvalue]
		end
		
		def extension_strings
			return nil if @accept_exts.empty?
			@accept_exts.compact.join('; ')
		end
		
		def <=>( other )
			if @type.nil?
				$stderr.puts "%s's type is more specific than %s" % [self, other]
				return 1 if ! other.type.nil?
			elsif other.type.nil?
				$stderr.puts "%s's type is less specific than %s" % [self, other]
				return -1 
			end
			
			if @subtype.nil?
				$stderr.puts "%s's subtype is less specific than %s" % [self, other]
				return 1 if ! other.subtype.nil?
			elsif other.subtype.nil?
				$stderr.puts "%s's subtype is less specific than %s" % [self, other]
				return -1 
			end
			
			if rval = (other.accept_exts.length <=> @accept_exts.length).nonzero?
				if rval < 1
					$stderr.puts "%s has more extensions than %s" % [self, other]
				else
					$stderr.puts "%s has fewer extensions than %s" % [self, other]
				end
					
				return rval
			end
			
			if rval = (other.qvalue <=> @qvalue).nonzero?
				if rval < 1
					$stderr.puts "%s has a higher qvalue than %s" % [self, other]
				else
					$stderr.puts "%s has a lower qvalue than %s" % [self, other]
				end

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
			media_range, *stuff = param.split( /\s*;\s*/ )
			qval, opts = stuff.partition {|par| par =~ /^q\s*=/ }
		
			rval << AcceptParam.new( media_range, qval.first, *opts )
		end
		
		return rval	
	end
	
end


start_irb_session( binding() )