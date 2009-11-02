#!/usr/bin/ruby
#
# ThingFish::UriMap -- a map of the server's urispace which determines
# which handlers are invoked for any URI.
#
# == Synopsis
#
#   require 'thingfish/urimap'
#
#
#   map = ThingFish::UriMap.new( fallback_handler )
#
#   handlers.each do |handler, uris|
#     uris.each do |uri|
#       map.register( handler, uri )
#     end
#   end
#
#   map[ request.uri ].each do |path, handler|
#     handler.dispatch( path, request )
#   end
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.

#


require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/constants'
require 'forwardable'

### Response wrapper class
class ThingFish::UriMap
	include ThingFish::Loggable,
	        ThingFish::Constants,
			ThingFish::HtmlInspectableObject

	### Create a new ThingFish::UriMap.
	def initialize
		@map = Hash.new {|h,k| h[ k ] = [] }
	end

	######
	public
	######

	# The Hash of paths to the Array of handlers that are registered there
	attr_reader :map


	### Return a human-readable representation of the object suitable
	### for debugging.
	def inspect
		return "#<%s:0x%x %s>" % [
			self.class.name,
			self.object_id * 2,
			@map.collect do |uri, handlers|
				"%p: [%s]" % [ uri, handlers.collect{|h| h.class.name}.join(", ") ]
			end.join('; ')
		]
	end


	### Associate the given +handler+ with a uri +path+.
	def register( path, handler )
		path = '' if path == '/'
		@map[ path ] << handler
	end


	### Associate the given +handler+ in front of any other handlers for that +path+.
	def register_first( path, handler )
		path = '' if path == '/'
		@map[ path ].unshift( handler )
	end


	### Return a flattened array of all registered handlers
	def handlers
		return @map.values.flatten
	end
	

	### Return the Array of handlers that are registered for the specified +path+.
	def handlers_for( path )
		path = '' if path == '/'
		return @map[ path ]
	end


	### Return an Array of the handlers which are registered as delegators
	### for the given +uri+.
	def delegators_for( uri )
		return self.resolve( uri ).first
	end


	### Return the handler which is ultimately responsible for handling requests
	### for the given +uri+.
	def processor_for( uri )
		return self.resolve( uri ).last
	end


	### Resolve the specified +uri+ into an Array of delegator handlers and a processor handler that
	### should handle the +uri+.
	def resolve( uri )
		if uri.is_a?( URI )
			path = uri.path
		else
			path = uri
		end

		handlers = []

		# For: "/admin/file_quota"
		# ''
		# 'admin'
		# 'admin/file_quota'

		last_path = path.sub( %r{^/}, '' ).scan( %r{[^/]+} ).inject( '' ) do |subpath,newdir|
			handlers += @map[ subpath ]
			subpath + '/' + newdir
		end
		handlers += @map[ last_path ]

		# [ delegators, processor ]
		return [ handlers[0..-2], handlers.last ]
	end
	alias_method :[], :resolve

end # ThingFish::UriMap

# vim: set nosta noet ts=4 sw=4:
