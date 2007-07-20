#!/usr/bin/ruby
#
# The metadata handler for the thingfish daemon. This handler provides
# a REST interface to metadata information.
#
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- metadata:
#           uris: /metadata
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
require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'


### The default top-level handler for the thingfish daemon
class ThingFish::MetadataHandler < ThingFish::Handler

	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		ThingFish::Loggable,
		ThingFish::StaticResourcesHandler,
        ThingFish::ResourceLoader

	static_resources_dir "static"


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new MetadataHandler
	def initialize( options={} )
		super

		@metastore = nil
	end


	######
	public
	######
	
	### Handle a request
	def process( request, response )
		super
		path = request.params['PATH_INFO']


		case request.params['REQUEST_METHOD']
		when 'GET'
			return self.handle_get_request( request, response )
			
		# The metadata handler doesn't care about anything else
		else
			response.start( HTTP::NOT_FOUND ) do |headers, out|
				out.write( "sucka foo" )
			end
			self.log.debug "No handler mapping for %p, falling through to static" % uri
		end
		
	rescue StandardError => err
		self.log.error "500 SERVER ERROR: %s" % [err.message]
		self.log.debug {"  " + err.backtrace.join("\n  ") }

		# If the response is already at least partially sent, we can't really do 
		# anything.
		if response.header_sent
			self.log.error "Exception occurred after headers were already sent."
			raise

		# If it's not, return a 500 response
		else
			response.reset
			response.start( HTTP::SERVER_ERROR, true ) do |headers, out|
				out.write( err.message )
			end
		end
	end


	#########
	protected
	#########

	### Handle a GET request
	def handle_get_request( request, response )
		uri = request.params['REQUEST_URI']
		
		# Attempt to serve upload form
		content = self.get_erb_resource( 'metadata.rhtml' )
		response.start( HTTP::OK, true ) do |headers, out|
			headers['Content-Type'] = 'text/html'
			out.write( content.result(binding()) )
		end
	end



end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
