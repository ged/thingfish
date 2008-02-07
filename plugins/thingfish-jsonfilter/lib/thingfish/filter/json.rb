#!/usr/bin/ruby
# 
# A JSON conversion filter for ThingFish
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          json: ~
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

require 'json'

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### A JSON-conversion filter for ThingFish. It converts Ruby objects in the body of responses 
### to JSON if the client accepts 'application/json'.
class ThingFish::JSONFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The Array of types this filter is interested in
	HANDLED_TYPES = [ ThingFish::AcceptParam.parse(RUBY_MIMETYPE) ]
	HANDLED_TYPES.freeze
	
	# The JSON mime type.
	JSON_MIMETYPE = 'application/json'
	JSON_MIMETYPE.freeze
	
	
	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options={} ) # :notnew:
		super
	end
	

	######
	public
	######

	### Filter incoming requests, converting from JSON to a native ruby object.
	def handle_request( request, response )
		
		# Only filter if the client sends what we can convert from.
		return unless request.content_type &&
			request.content_type.downcase == JSON_MIMETYPE
		
		# Absorb errors so filters can continue
		begin
			self.log.debug "Converting a %s request to %s" %
				[ JSON_MIMETYPE, RUBY_MIMETYPE ]
			request.body = JSON.parse( request.body.read )
		rescue JSON::ParserError => err
			self.log.error "%s while attempting to convert %p to a native ruby object: %s" %
				[ err.class.name, request.body, err.message ]
			self.log.debug err.backtrace.join("\n")	
		else
			request.content_type = RUBY_MIMETYPE
		end
	end


	### Convert outgoing ruby object responses into JSON.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.explicitly_accepts?( JSON_MIMETYPE ) &&
			self.accept?( response.content_type )
		
		# Errors converting to JSON should result in a 500.
		self.log.debug "Converting a %s response to application/json" %
			[ response.content_type ]
		response.body = response.body.to_json
		response.content_type = JSON_MIMETYPE
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end
	
	
end # class ThingFish::JSONFilter

# vim: set nosta noet ts=4 sw=4:


