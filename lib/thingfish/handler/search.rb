#!/usr/bin/ruby
#
# The search handler for the thingfish daemon. This handler provides a REST
# interface to searching for resources which match criteria concerning their
# associated metadata.
#
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- search: ~
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
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'


### The default search handler for the thingfish daemon
class ThingFish::SearchHandler < ThingFish::Handler

	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		ThingFish::Loggable,
		ThingFish::StaticResourcesHandler,
        ThingFish::ResourceLoader

	static_resources_dir "static"


	# SVN Revision
	SVNRev = %q$Rev: 331 $

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new SearchHandler
	def initialize( options={} )
		super

		@metastore = nil
	end


	######
	public
	######
	
	### Handle a GET request
	def handle_get_request( request, response )

		uri  = request.uri.path
		args = request.query_args

		uuids = @metastore.find_by_exact_properties( args )

		response.status = HTTP::OK
		if request.accepts?( 'text/html' )
			content = self.get_erb_resource( 'search.rhtml' )
			response.body = content.result( binding() )
			response.headers[:content_type] = 'text/html'
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = uuids
		end
	end

end # ThingFish::SearchHandler

# vim: set nosta noet ts=4 sw=4:
