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
		self.log.debug "Handling inspection request"
		# return unless request.path_info == ''

		content = self.get_erb_resource( 'inspect.rhtml' )
		inspected_objects = [
			object_section( "Daemon", self.listener ),
			object_section( "Request", request ),
			object_section( "Request Body", request.body.read ),
			object_section( "Request Body Size", request.body.length ),
			object_section( "Headers", request.headers.to_h ),
			object_section( "Response", response ),
			object_section( "Handler", self ),
		]
		
		response.headers[ :content_type ] = 'text/html'
		response.body = content.result( binding() )
		response.status = HTTP::OK
	end
	
	
	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
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
