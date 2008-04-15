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

begin
	require 'pp'
	require 'rbconfig'
	require 'pathname'
	require 'thingfish/mixins'
	require 'thingfish/handler'
	require 'thingfish/constants'
	require 'thingfish/exceptions'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


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
		requested_object = request.path_info
		inspected_object = nil
	
		# Set the body of the response according to the path of the URI
		case requested_object
		when '', '/'
			response.data[:title] = "ThingFish Introspection"
			inspected_object = {
				'daemon'   => 'ThingFish::Daemon',
				'request'  => 'ThingFish::Request',
				'response' => 'ThingFish::Response',
				'config'   => 'ThingFish::Config',
			}
			
		when /config/i
			response.data[:title] = "The Server's Config (ThingFish::Config)"
			inspected_object = self.listener.config
			
		when /daemon/i
			response.data[:title] = "The Server Object (ThingFish::Daemon)"
			inspected_object = self.listener

		when /request/i
			response.data[:title] = "The Current Request Object (ThingFish::Request)"
			inspected_object = request
		
		when /response/i
			response.data[:title] = "The Current Response Object (ThingFish::Response)"
			inspected_object = response

		else
			self.log.error "Unsupported inspection request for: %p" % [requested_object]
			return
		end

		response.status = HTTP::OK
		response.data[:tagline] = 'Dissect me!'
		response.body = inspected_object
		response.content_type = RUBY_MIMETYPE
	end


	### Make an HTML fragment for the body text/html response (HTML filter API).
	def make_html_content( body, request, response )
		content = self.get_erb_resource( 'inspect.rhtml' )
		response.content_type = CONFIGURED_HTML_MIMETYPE
		return content.result( binding() )
	end
	
	
	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
		return tmpl.result( binding() )
	end
	
end # class ThingFish::InspectHandler

# vim: set nosta noet ts=4 sw=4:
