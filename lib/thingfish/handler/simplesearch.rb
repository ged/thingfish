#!/usr/bin/ruby
#
# A search handler for the thingfish daemon. This handler provides a REST
# interface to searching for resources which match criteria concerning their
# associated metadata in a ThingFish::SimpleMetastore.
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     urimap:
#       /search: simplesearch
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
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/metastore/simple'
require 'thingfish/mixins'


### The search handler for the thingfish daemon when it's using a
### ThingFish::SimpleMetaStore.
class ThingFish::SimpleSearchHandler < ThingFish::Handler

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

	### Set up a new SearchHandler
	def initialize( path, options={} )
		super

		@metastore = nil
	end


	######
	public
	######

	### Handle a GET request
	def handle_get_request( path_info, request, response )
		args = request.query_args.reject { |k,v| v.nil? }

		uuids = if args.empty?
			[]
		else
			@metastore.find_by_matching_properties( args )
		end

		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = uuids
	end


	### Make the content for the handler section of the index page.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "search/index.rhtml" )
		return tmpl.result( binding() )
	end


	### Generate an HTML fragment for the uuids in the given +body+.
	def make_html_content( uuids, request, response )
		args = request.query_args
		uri  = request.uri.path

		response.data[:tagline] = 'Interrogate me.'
		response.data[:title] = 'search'
		response.data[:head]  = %Q{
	<script src="/js/search.js" type="text/javascript" charset="utf-8"></script>
		}

		template = self.get_erb_resource( 'search/main.rhtml' )
		content = template.result( binding() )

		return content
	end
	
end # ThingFish::SearchHandler

# vim: set nosta noet ts=4 sw=4:
