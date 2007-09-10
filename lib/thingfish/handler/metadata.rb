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


### The default metadata handler for the thingfish daemon
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
	
	### Handle a GET request
	def handle_get_request( request, response )
		metadata_keys = @metastore.get_all_property_keys.collect {|k| k.to_s }
		
		# Attempt to serve metadata list html
		response.status = HTTP::OK
		
		if request.accepts?( 'text/html' )
			content = self.get_erb_resource( 'metadata.rhtml' )
			response.body = content.result( binding() )
			response.headers[:content_type] = 'text/html'
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = metadata_keys
		end
	end



end # ThingFish::MetadataHandler

# vim: set nosta noet ts=4 sw=4:
