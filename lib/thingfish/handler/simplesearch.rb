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


	# The character that separates search criteria
	TERM_SEPARATOR = ';'


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
	def handle_get_request( search_terms, request, response )
		terms = self.split_terms( search_terms )
		self.log.debug "Query args are: %p" % [ request.query_args ]

		if request.query_args.key?( 'full' )
			self.log.debug "Handling a full search request"
			self.handle_full_search_request( request, response, terms )
		else
			self.log.debug "Handling a UUID search request"
			self.handle_uuid_search_request( request, response, terms )
		end
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


	#########
	protected
	#########

	### Handle a search request and return a UUID for each result.
	def handle_uuid_search_request( request, response, terms )
		order, limit, offset = self.normalize_search_arguments( request )
		self.log.debug "Handling UUID search request for terms=%p, order=%p, limit=%p, offset=%p" %
			[ terms, order, limit, offset ]

		# :TODO: Modify this to use #find_by_exact if possible.
		tuples = if terms.empty?
		        	[]
		        else
		        	@metastore.find_by_matching_properties( terms, order, limit, offset )
		        end

		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = tuples.collect {|pair| pair.first }
	end


	### Handle a search request and return full metadata for each result.
	def handle_full_search_request( request, response, terms )
		order, limit, offset = self.normalize_search_arguments( request )
		self.log.debug "Handling full search request for terms=%p, order=%p, limit=%p, offset=%p" %
			[ terms, order, limit, offset ]

		# :TODO: Modify this to use #find_by_exact if possible.
		tuples = if terms.empty?
		        	[]
		        else
		        	@metastore.find_by_matching_properties( terms, order, limit, offset )
		        end

		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = tuples
	end


	### Split the terms in the given +termstring+ into a Hash, keyed by symbol.
	def split_terms( termstring )
		raise ThingFish::RequestError,
			"extraneous path info in search terms" if termstring.index('/')

		self.log.debug "Splitting terms from term string %p" % [ termstring ]
		pairs = URI.decode( termstring ).split( TERM_SEPARATOR )

		terms = pairs.inject( {} ) do |terms, pair|
			key, value = pair.split( '=', 2 )
			terms[ key ] = value
			terms
		end
		self.log.debug "  terms are: %p" % [ terms ]

		return terms
	end


	### Extract search parameters from the given query +args+ and return them as 
	### normalized values.
	def normalize_search_arguments( request )
		args   = request.query_args
		limit  = args[:limit].to_i.nonzero? || DEFAULT_LIMIT
		offset = args[:offset].to_i

		order = case args[:order]
			when Array
				args[:order]
			when String
				args[:order].split( /\s*,\s*/ )
			else
				[]
			end

		order = order.reject {|prop| prop !~ PROPERTY_NAME_REGEXP }.collect {|field| field.to_sym }

		return order, limit, offset
	end

end # ThingFish::SearchHandler

# vim: set nosta noet ts=4 sw=4:
