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
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
# 
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'pathname'
require 'pluginfactory'
require 'mongrel/handlers'
require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/daemon'


### Mixin for ThingFish Handler plugins
class ThingFish::Handler
	include PluginFactory,
		Mongrel::HttpHandlerPlugin,
		ThingFish::Loggable,
		ThingFish::ResourceLoader


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Pattern to match valid http method handlers
	HANDLER_PATTERN = /^handle_([a-z]+)_request$/


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Return an Array of prefixes to use when searching for derivatives.
	def self::derivative_dirs
		['thingfish/handler']
	end
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Handler object
	def initialize( options={} )
		@resource_dir = options['resource_dir'] || options[:resource_dir]
		@filestore    = nil
		@metastore    = nil
		@config       = nil

		super
	end
	

	######
	public
	######

	### Do some consistent stuff for each handler.
	def process( request, response )
		self.log_request( request )
		response.header['Server'] = ThingFish::Daemon::SERVER_SOFTWARE_DETAILS
		
		http_method  = request.params['REQUEST_METHOD']
		handler_name = "handle_%s_request" % [http_method.downcase]
		self.log.debug "Searching for a %s handler method: %s#%s" %
			[ http_method, self.class.name, handler_name ]
		
		# Look up the handler for the request's HTTP method
		if self.respond_to?( handler_name )
			self.send( handler_name, request, response )

		else
			self.log.warn( "Refusing to handle a #{http_method} request" )
			self.send_method_not_allowed_response( response, http_method )
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
	

	### Set the handler's filestore and metastore object in the handler (callback 
	### from the daemon when the handler is registered)
	def listener=( listener )
		@filestore = listener.filestore
		@metastore = listener.metastore
		@config    = listener.config
		super
	end


	### If the handler should be linked from the main index HTML page, return an
	### HTML fragment linking it to the specified +uri+. Returning +nil+ (the 
	### default) means that this handler shouldn't be linked.
	def make_index_content( uri )
		# return %{<a href="%s">%s</a>} % [uri, self.class.name] # For testing
		return nil
	end
	


	#########
	protected
	#########

	### Log requests to uris in a consistent fashion.
	### This hopefully will go away at a future date when/if mongrel supports a 
	### hook for process_client()
	def log_request( request )
		self.log.info( self.class.name ) {
			"%s %s %s" % [ 
				request.params['REMOTE_ADDR'],
				request.params['REQUEST_METHOD'],
				request.params['REQUEST_URI'] 
			  ]
		}
	end
	

	### Send a METHOD_NOT_ALLOWED response using the given +response+ object. 
	### The +valid_methods+ parameter is used to build the 'Allow' header --
	### it should be either a String (which is used as the content of the 
	### header) or an Array of valid methods (which is concatenated to form
	### the header). If it is +nil+, the valid methods are derived via
	### introspection.
	def send_method_not_allowed_response( response, request_method, valid_methods=nil )
		self.log.error "Method %p not allowed; sending NOT_ALLOWED response" %
			[request_method]
	
		valid_methods ||= self.methods.
			select  {|name| name =~ HANDLER_PATTERN }.
			collect {|name| name[HANDLER_PATTERN, 1].upcase }
			
		if valid_methods.respond_to?( :sort )
			allowed_methods = valid_methods.sort.join(', ')
		else
			allowed_methods = valid_methods
		end

		self.log.debug "Allowed methods are: %p" % [allowed_methods]
		response.start( HTTP::METHOD_NOT_ALLOWED, true ) do |headers, out|
			headers['Allow'] = allowed_methods
			out.write( "%s method not allowed." % request_method )
		end
	end
	

	### Return the +uris+ this handler is registered to
	def find_handler_uris
		map = @listener.classifier.handler_map.invert
		
		uris = []
		map.each do |handlers, uri|
			case handlers
			when ThingFish::Handler
				uris << uri if handlers == self
			when Array
				uris << uri if handlers.include?( self )
			else
				self.log.warn "Don't know how to traverse handler map %p for %p" %
				 	[handlers, uri]
			end
		end
		
		return uris
	end
	

end # class ThingFish::Handler

# vim: set nosta noet ts=4 sw=4:

