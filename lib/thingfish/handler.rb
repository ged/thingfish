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
# :include: LICENSE
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
require 'thingfish/constants'
require 'thingfish/daemon'


### Base class for ThingFish Handler plugins
class ThingFish::Handler
	include PluginFactory,
		Mongrel::HttpHandlerPlugin,
		ThingFish::Loggable,
		ThingFish::ResourceLoader,
		ThingFish::Constants,
		ThingFish::HtmlInspectableObject


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

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

	
	### PluginFactory interface: Return a sprintf string which describes the naming
	### convention of plugin gems for this class. The results will be used as an
	### argument to the 'Kernel::gem' function.
	def self::rubygem_name_pattern
		'thingfish-%shandler'
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

	# Rename the listener reader to reflect its name in ThingFish-land
	alias_method :daemon, :listener


	### Do some consistent stuff for each handler.
	def process( request, response )
		self.log_request( request )
		
		http_method = request.http_method
		handler_name = "handle_%s_request" % [ http_method.downcase ]
		self.log.debug "Searching for a %s handler method: %s#%s" %
			[ http_method, self.class.name, handler_name ]
		
		# Look up the handler for the request's HTTP method
		if self.respond_to?( handler_name )
			self.send( handler_name, request, response )

		else
			self.log.warn "Refusing to handle a %s request for %s" % [
				http_method, request.uri.path
			]
			self.send_method_not_allowed_response( response, http_method )
		end
	end
	

	### Set the handler's filestore, metastore, and config object in the handler
	### (callback from the daemon when the handler is registered)
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

	
	### Convert the given +body+ object to HTML for a text/html response. By default,
	### this just hands back a pretty-printed HTML version of the body object --
	### override this to do something fancier/more useful.
	def make_html_content( body, request, response )
		return body.html_inspect
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
				request.remote_addr,
				request.http_method,
				request.uri.path
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
	
		valid_methods ||= self.methods.
			select  {|name| name =~ HANDLER_PATTERN }.
			collect {|name| name[HANDLER_PATTERN, 1].upcase }
			
		if valid_methods.respond_to?( :sort )
			allowed_methods = valid_methods.sort.join(', ')
		else
			allowed_methods = valid_methods
		end

		self.log.debug "Allowed methods are: %p" % [allowed_methods]
		response.status = HTTP::METHOD_NOT_ALLOWED
		response.headers[:allow] = allowed_methods
		response.body = "%s method not allowed." % request_method
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

