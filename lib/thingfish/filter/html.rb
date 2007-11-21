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
		ThingFish::Constants,
		ThingFish::ResourceLoader

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


	### Convert outgoing ruby object responses into HTML.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response
		# body is something we know how to convert
		return unless request.explicitly_accepts?( 'text/html' ) &&
			self.accept?( response.headers[:content_type] )

		self.log.debug "Converting a %s response to text/html" %
			[ response.headers[:content_type] ]
		
		# Find the handlers that can make html
		content = []
		handlers = response.handlers.reverse.find_all {|h| h.respond_to?(:make_html_content) }

		# Either ask the handlers for content, or just return the inspected body object
		if handlers.empty?
			content << response.body.html_inspect
		else
			handlers.each do |handler|
				self.log.debug "Fetching HTML content from %s" % [ handler.class.name ]
				content << handler.make_html_content( response.body, request, response )
			end
		end

		template = self.get_erb_resource( 'template.rhtml' )
		
		response.body = template.result( binding() )
		response.headers[:content_type] = 'text/html'
		response.status = HTTP::OK
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end

end # class ThingFish::HtmlFilter

# vim: set nosta noet ts=4 sw=4:

