#!/usr/bin/ruby
#
# Output a quick inspection page
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- inspect: ['/admin/inspect', '/whatever/inspect']
#		- pork: /admin/inspect
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

require 'pp'
require 'rbconfig'
require 'pathname'
require 'thingfish/mixins'
require 'thingfish/handler'


### Output a quick inspection page
class ThingFish::InspectHandler < ThingFish::Handler
	include ThingFish::Loggable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Handle a request
	def process( request, response )
		params = request.params
		self.log_request( request )
		
		response.start(200) do |headers, out|
			headers["Content-Type"] = "text/html"

			html = page do
				object_section( "Daemon", self.listener ) +
				object_section( "Request", request ) +
				object_section( "Request Body", request.body.read ) +
				object_section( "Request Body Size", request.body.length ) +
				object_section( "Headers", headers ) +
				object_section( "Response", response ) +
				object_section( "Handler", self )
			end

			out.write( html )
		end
	end


	### Wrap the results of a block in an HTML page.
	def page
		content = yield
		page = get_resource( 'index.html' )
		return page % [ content ]
	end


	### Wrap the inspected +object+ in an HTML fragment and return it.
	def object_section( title, object )
		buf = ''
		PP.pp( object, buf )

		return %{<div class="object-section"><h3>%s</h3><pre>%s</pre></div>\n\n} % [
			title,
			buf.gsub( /&/, '&amp;' ).
				gsub( /</, '&lt;' ).
				gsub( />/, '&gt;' ).
				gsub( /"/, '&quot;' )
		]
	end


end # class ThingFish::InspectHandler

# vim: set nosta noet ts=4 sw=4:
