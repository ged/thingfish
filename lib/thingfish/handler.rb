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
		super
	end
	

	######
	public
	######

	### Do some consistent stuff for each handler.
	def process( request, response )
		self.log_request( request )
		response.header['Server'] = ThingFish::Daemon::SERVER_SOFTWARE_DETAILS
	end
	

	### Set the handler's filestore and metastore object in the handler (callback 
	### from the daemon when the handler is registered)
	def listener=( listener )
		@filestore = listener.filestore
		@metastore = listener.metastore
		@config    = listener.config
		super
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

