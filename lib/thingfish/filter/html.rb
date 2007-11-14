#!/usr/bin/ruby
# 
# An HTML conversion filter for ThingFish
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          html: ~
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
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### An HTML-conversion filter for ThingFish. It converts Ruby objects in the body 
### of responses to HTML if the client accepts 'text/html'.
class ThingFish::HtmlFilter < ThingFish::Filter
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
		@config = nil
		super()
	end
	

	######
	public
	######

	### Filter incoming requests (no-op currently)
	def handle_request( request, response )
	end


	### Convert outgoing ruby object responses into HTML.
	def handle_response( response, request )
		
		# Only filter if the client wants what we can convert to, and the response
		# body is something we know how to convert
		return unless request.explicitly_accepts?( 'text/html' ) &&
			self.accept?( response.headers[:content_type] )

		handler = response.handlers.last
		
		self.log.debug "Converting a %s response to text/html" %
			[ response.headers[:content_type] ]
		
		# title
		# head injection
		
		response.body = handler.make_html_content( response.body, request, response )
		response.headers[:content_type] = 'text/html'
		response.status = HTTP::OK
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end

	#########
	protected
	#########
	
	def poop
	end
	
end # class ThingFish::HtmlFilter

# vim: set nosta noet ts=4 sw=4:

