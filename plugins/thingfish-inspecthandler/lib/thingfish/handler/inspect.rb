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
require 'thingfish/constants'


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
		self.log.debug "Inspect handler GET response"
		return unless request.params['PATH_INFO'] == ''

		# Attempt to serve upload form
		content = self.get_erb_resource( 'inspect.rhtml' )
		response.start( HTTP::OK, true ) do |headers, out|
			self.log.debug "Start of response to the inspect handler"
			inspected_objects = [
				object_section( "Daemon", self.listener ),
				object_section( "Request", request ),
				object_section( "Request Body", request.body.read ),
				object_section( "Request Body Size", request.body.length ),
				object_section( "Headers", headers ),
				object_section( "Response", response ),
				object_section( "Handler", self ),
			]
		
			self.log.debug "Setting content type"
			headers['Content-Type'] = 'text/html'
			out.write( content.result(binding()) )
		end
	end
	
	
	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.html" )
		return tmpl.result( binding() )
	end
	

	### Generated a prettyprinted inspect of the given +object+ and return it in
	### a hash with the specified +title+.
	def object_section( title, object )
		buf = ''
		PP.pp( object, buf )

		return { :title => title, :object => buf }
	end


end # class ThingFish::InspectHandler

# vim: set nosta noet ts=4 sw=4:
