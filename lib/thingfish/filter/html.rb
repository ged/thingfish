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
# Please see the file LICENSE in the top-level directory for licensing details.

#


require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### An HTML-conversion filter for ThingFish. It converts Ruby objects in the body
### of responses to HTML if the client accepts CONFIGURED_HTML_MIMETYPE.
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
	def initialize( options=nil ) # :notnew:
		options ||= {}
		@resource_dir = options['resource_dir'] || options[:resource_dir]
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
		return unless request.explicitly_accepts?( CONFIGURED_HTML_MIMETYPE ) &&
			self.accept?( response.content_type )

		self.log.debug "Converting a %s response to %s" %
			[ response.content_type, CONFIGURED_HTML_MIMETYPE ]

		# Find the handlers that can make html
		processor = response.handlers.last or raise "Oops! No processor for %s?!?" % [ request.uri.path ]
		content = nil
		
		if processor.respond_to?( :make_html_content )
			content = processor.make_html_content( response.body, request, response )
		else
			content = response.body.html_inspect
		end

		template = self.get_erb_resource( 'template.rhtml' )

		response.body = template.result( binding() )
		response.content_type = CONFIGURED_HTML_MIMETYPE
	end


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [ 1, 0 ],                    # Filter version
	###     'supports'  => [],                          # Unused
	###     'rev'       => 460,                         # SVN rev of plugin
	###     'accepts'   => [''],                        # Mimetypes the filter accepts from requests
	###     'generates' => ['application/xhtml+xml'],   # Mimetypes the filter can convert responses to
	###   }
	def info
		return {
			'version'   => [1,0],
			'supports'  => [],
			'rev'       => Integer( SVNRev[/\d+/] || 0 ),
			'accepts'   => [],
			'generates' => [CONFIGURED_HTML_MIMETYPE],
		  }
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end

end # class ThingFish::HtmlFilter

# vim: set nosta noet ts=4 sw=4:

