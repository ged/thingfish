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

	### Filter incoming requests (no-op currently)
	def handle_request( request, response )
	end


	### Convert outgoing ruby object responses into JSON.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.explicitly_accepts?( 'application/json' ) &&
			self.accept?( response.headers[:content_type] )
		
		# Absorb errors so filters can continue
		begin
			self.log.debug "Converting a %s response to application/json" %
				[ response.headers[:content_type] ]
			response.body = response.body.to_json
		rescue => err
			self.log.error "%s while attempting to convert %p to JSON: %s" %
				[ err.class.name, response.body, err.message ]
		else
			response.headers[:content_type] = 'application/json'
			response.status = HTTP::OK
		end
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end
	
	
end # class ThingFish::JSONFilter

# vim: set nosta noet ts=4 sw=4:


