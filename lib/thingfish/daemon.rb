#!/usr/bin/ruby
#
# ThingFish daemon class
#
# == Synopsis
#
#   require 'thingfish/daemon'
#   require 'thingfish/config'
#
#   config = ThingFish::Config.load( "thingfish.conf" )
#   server = ThingFish::Daemon.new( config )
#   
#   accepter = server.run  # => #<Thread:0x142317c sleep>
#   
#   Signal.trap( "INT" ) { server.shutdown("Interrupted") }
#   Signal.trap( "TERM" ) { server.shutdown("Terminated") }
# 
#   accepter.join
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

require 'thingfish'
require 'mongrel'
require 'uuidtools'
require 'etc'
require 'logger'

require 'thingfish/constants'
require 'thingfish/config'
require 'thingfish/mixins'
require 'thingfish/filestore'
require 'thingfish/metastore'
require 'thingfish/handler'


### ThingFish daemon class
class ThingFish::Daemon < Mongrel::HttpServer
	include ThingFish::Constants, ThingFish::Loggable

	SVNId = %q$Id$
	SVNRev = %q$Rev$

	# Constants for HTTP headers
	SERVER_VERSION = '0.0.1'
	SERVER_SOFTWARE = "ThingFish/#{SERVER_VERSION}"
	SERVER_SOFTWARE_DETAILS = "#{SERVER_SOFTWARE} (#{SVNRev})"

	# Options for the default handler
	DEFAULT_HANDLER_OPTIONS = {}


	### Create a new ThingFish daemon object that will listen on the specified +ip+
	### and +port+.
	def initialize( config=nil )
		@config = config || ThingFish::Config.new
		@config.install

		# Load plugins for filestore, filters, and handlers
		@filestore = @config.create_configured_filestore
		@metastore = @config.create_configured_metastore

		super( @config.ip, @config.port )
		self.log.info "Starting at: http://%s:%d/" % [ @config.ip, @config.port ]

		# Register all the handlers
		self.register( "/", self.create_default_handler(@config) )
		@config.each_handler_uri do |handler, uri|
			self.log.info "  registering %s at %p" % [handler.class.name, uri]
			self.register( uri, handler, handler.options['in_front'] )
		end
		
		self.log.debug {
			"Handler map is:\n    " + 
			self.classifier.handler_map.collect {|uri, handlers|
				"%s: [%s]" % [ uri, handlers.collect{|h| h.class.name}.join(", ") ]
			}.join( "\n    ")
		}
	end

	######
	public
	######

	# The ThingFish::FileStore instance that acts as the interface to the file storage
	# mechanism used by the daemon.
	attr_reader	:filestore

	# The ThingFish::MetaStore instance that acts as the interface to the metadata
	# mechanism used by the daemon.
	attr_reader :metastore

	# The ThingFish::Config instance that contains all current configuration
	# information used by the daemon.
	attr_reader :config


	### Perform any additional daemon actions before actually starting
	### the Mongrel side of things.
	def run
		# Drop privileges if we're root, and we're configged to do so.
		if Process.euid.zero? and ! @config.user.nil?
			self.log.debug "Dropping privileges (user: %s)" % @config.user
			Process.euid = Etc.getpwnam( @config.user ).uid
		end

		super
	end


	### Shut the server down gracefully, outputting the specified +reason+ for the
	### shutdown to the logs.
	def shutdown( reason="no reason" )
		self.log.warn "Shutting down: #{reason}"
		self.stop
	end


	#########
	protected
	#########

	### Create an instance of the default handler, with options dictated by the
	### specified +config+ object.
	def create_default_handler( config )
		options = DEFAULT_HANDLER_OPTIONS.dup
		if config.defaulthandler
			options.merge!( config.defaulthandler )
		end
		
		return ThingFish::Handler.create( 'default', options )
	end
	

end # class ThingFish::Daemon

# vim: set nosta noet ts=4 sw=4:
