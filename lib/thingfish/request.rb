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


### Resource wrapper class
class ThingFish::Request
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Create a new ThingFish::Request wrapped around the given +mongrel_request+.
	def initialize( mongrel_request )
		@mongrel_request = mongrel_request
		@headers = nil
	end


	######
	public
	######

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
	

end # ThingFish::Request

# vim: set nosta noet ts=4 sw=4:
