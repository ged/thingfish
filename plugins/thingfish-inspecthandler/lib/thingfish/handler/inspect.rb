#!/usr/bin/ruby
#
# Output a quick inspection page
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- inspect:
#           uris: ['/admin/inspect', '/whatever/inspect']
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

require 'pp'
require 'rbconfig'
require 'pathname'
require 'thingfish/mixins'
require 'thingfish/handler'
require 'thingfish/constants'
require 'thingfish/exceptions'


### Output a quick inspection page
class ThingFish::InspectHandler < ThingFish::Handler
	include ThingFish::Loggable,
		ThingFish::Constants,
		ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Handler API: handle a GET request with an inspection page.
	def handle_get_request( request, response )
		if request.accepts?( "text/html" )
			requested_object = request.path_info
			inspected_object = nil
		
			# Set the `inspected_object`, which is referenced via the Binding by 
			# the template
			case requested_object
			when /daemon/i
				inspected_object = self.listener.html_inspect

			when /request/i
				inspected_object = request.html_inspect
			
			when /response/i
				inspected_object = response.html_inspect

			end

			content = self.get_erb_resource( 'inspect.rhtml' )
			response.headers[ :content_type ] = 'text/html'
			response.body = content.result( binding() )
			response.status = HTTP::OK
		else
			raise ThingFish::RequestNotAcceptableError,
				"don't know how to satisfy a request for %p" % [ request.headers[:accept] ]
		end
	end
	
	
	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
		return tmpl.result( binding() )
	end
	
end # class ThingFish::InspectHandler

# vim: set nosta noet ts=4 sw=4:
