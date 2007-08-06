#!/usr/bin/ruby
# 
# ThingFish::Response -- a wrapper around a Mongrel::HttpResponse, providing
# a unified spot for current HTTP status, response headers, data to be
# returned to the client, and bindings to the responding handler methods.
# 
# == Synopsis
# 
#   require 'thingfish/response'
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
# - the HTTP status
# - the data to be returned (as either a String or an IO)
# - bindings to the handler methods of all of the responding handlers,
#     which will allow things like ERb to eval back into them after the 
#     content-type filter knows the client wants HTML.


require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/multipartmimeparser'
require 'forwardable'

### Response wrapper class
class ThingFish::Response
	include ThingFish::Loggable,
	        ThingFish::Constants
	
	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	### Create a new ThingFish::Response wrapped around the given
	### +mongrel_response+.
	### The specified +spooldir+ will be used for spooling uploaded files, 
	def initialize( mongrel_response )
		@mongrel_response = mongrel_response

		@headers  = ThingFish::Table.new
		@body     = ''
		@status   = HTTP::OK
		@bindings = {}
	end


	######
	public
	######

	# Methods that fall through to the Mongrel response object
	# def_delegators :@mongrel_response, :body
	
	# The original Mongrel::HttpResponse object
	attr_reader :mongrel_response

	# The response headers (a ThingFish::Table)
	attr_reader :headers

	# The response body
	attr_accessor :body
	

end # ThingFish::Response

# vim: set nosta noet ts=4 sw=4:
