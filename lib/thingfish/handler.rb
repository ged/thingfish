#!/usr/bin/ruby
#
# The base HTTP handler type for ThingFish
#
# == Synopsis
#
#   require 'thingfish/handler'
#
#   class MyHandler < ThingFish::Handler
#
#   end
#
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

begin
	require 'pathname'
	require 'pluginfactory'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/daemon'


### Base class for ThingFish Handler plugins
class ThingFish::Handler
	include PluginFactory,
		ThingFish::Loggable,
		ThingFish::ResourceLoader,
		ThingFish::Constants,
		ThingFish::HtmlInspectableObject


	# Pattern to match valid http method handlers
	HANDLER_PATTERN = /^handle_([a-z]+)_request$/


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### PluginFactory interface: Return an Array of prefixes to use when searching
	### for derivatives.
	def self::derivative_dirs
		['thingfish/handler']
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Handler object that will answer requests on the given +path+.
	def initialize( path, options={} )
		@resource_dir = options['resource_dir'] || options[:resource_dir]
		@filestore    = nil
		@metastore    = nil
		@config       = nil
		@daemon       = nil
		@options      = options
		@path         = path

		super()

		self.log.debug "%s created with resource dir at: %p" % [ self.class.name, @resource_dir ]
	end


	######
	public
	######

	# The ThingFish::Daemon that this handler is registered to
	attr_reader :daemon

	# The options the handler was constructed with
	attr_reader :options


	### Run as a delegator for the specified +request+ and +response+. Handlers are run
	### as delegators when they are mapped in front of other handlers in the urispace.
	### Subclasses that want to override this behavior should yield the +request+ and
	### +response+ objects, and then return the +request+ and +response+ objects returned by
	### the +yield+ call.
	def delegate( request, response )
		self.log.debug "Using default (no-op) delegation"
		res = yield( request, response )
		self.log.debug "Back from delegation"
		
		return res
	end
	

	### Handle the actions indicated by the +request+ and return the results in 
	### the given +response+.
	def process( request, response )
		self.log_request( request )

		http_method = request.http_method
		http_method = :GET if http_method == :HEAD

		handler_name = "handle_%s_request" % [ http_method.to_s.downcase ]
		self.log.debug "Searching for a %s handler method: %s#%s" %
			[ http_method, self.class.name, handler_name ]

		# Look up the handler for the request's HTTP method
		if self.respond_to?( handler_name )
			self.send( handler_name, self.path_info(request), request, response )

		else
			self.log.warn "Refusing to handle a %s request for %s" % [
				http_method, request.uri.path
			]
			self.build_method_not_allowed_response( response, http_method )
		end
	end


	### Set the handler's filestore, metastore, and config object from the Daemon
	### startup callback.
	def on_startup( daemon )
		@filestore = daemon.filestore
		@metastore = daemon.metastore
		@config    = daemon.config
		@daemon    = daemon
	end


	### If the handler should be linked from the main index HTML page, return an
	### HTML fragment linking it to the specified +uri+. Returning +nil+ (the
	### default) means that this handler shouldn't be linked.
	def make_index_content( uri )
		# return %{<a href="%s">%s</a>} % [uri, self.class.name] # For testing
		return nil
	end


	### Return the given +request+'s URI relative to the handler's path in the 
	### server's urispace.
	def path_info( request )
		request_path = request.uri.path.dup

		unless request_path == ''
			request_path.sub!( /^#{@path}/, '' ) or
				raise ThingFish::DispatchError, "request uri %p does not include %p" %
				[ request.uri.to_s, @path ]
		end
		
		return request_path.sub( %r{^/}, '' )
	end
	


	#########
	protected
	#########

	### Log requests to uris in a consistent fashion.
	def log_request( request )
		self.log.info {
			"%s %s %s {%s}" % [
				request.remote_addr,
				request.http_method,
				request.uri.path,
				request.headers.user_agent || 'unknown',
			]
		}
	end


	### Send a METHOD_NOT_ALLOWED response using the given +response+ object.
	### The +valid_methods+ parameter is used to build the 'Allow' header --
	### it should be an Array of valid methods (which is concatenated to form
	### the header). If it is +nil+, the valid methods are derived via
	### introspection.
	def build_method_not_allowed_response( response, request_method, valid_methods=nil )

		# Build a list of valid methods based on introspection
		valid_methods ||= self.methods.
			select  {|name| name =~ HANDLER_PATTERN }.
			collect {|name| name[HANDLER_PATTERN, 1].upcase }

		# Automatically handle HEAD requests if GET is allowed
		valid_methods.push('HEAD') if valid_methods.include?('GET')

		allowed_methods = valid_methods.uniq.sort.join(', ')

		self.log.debug "Allowed methods are: %p" % [allowed_methods]
		response.status = HTTP::METHOD_NOT_ALLOWED
		response.headers[:allow] = allowed_methods
		response.body = "%s method not allowed." % request_method
	end
	
end # class ThingFish::Handler

# vim: set nosta noet ts=4 sw=4:

