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

	### Override Mongrel's handler-processing to incorporate filters, and our own 
	### request and response objects.
	def dispatch_to_handlers( client, handlers, mongrel_request, mongrel_response )
		# request  = ThingFish::HttpRequest( mongrel_request )
		# response = ThingFish::HttpResponse( mongrel_response )
	
		self.log.debug "Dispatching to %d handlers" % [handlers.length]
		handlers.each do |handler|
			handler.process( mongrel_request, mongrel_response )
			break if client.closed?
		end
		
		# mongrel_response.start( response.status, true ) do |headers, out|
		# 	# Since Mongrel thinks it knows *all* the headers which can be 
		# 	# duplicated, we have to write to the HeaderOut's buffer ourselves
		# 	response.headers do |header, value|
		# 		headers.out.write( "%s: %s\r\n" % [header, value] )
		# 	end
		# 	
		# 	if response.body.respond_to?( :read )
		# 		# TODO: buffer outbound IO
		# 		out.write( response.body.read )
		# 	else
		# 		out.write( response.body.to_s )
		# 	end
		# end
	end
	


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



####################################################################################
###  BEGIN MONKEY EEK EEEK EEEEEEEEEEK
####################################################################################
class Mongrel::HttpServer
	include Mongrel
	
	# Does the majority of the IO processing.  It has been written in Ruby using
	# about 7 different IO processing strategies and no matter how it's done 
	# the performance just does not improve.  It is currently carefully constructed
	# to make sure that it gets the best possible performance, but anyone who
	# thinks they can make it faster is more than welcome to take a crack at it.
	def process_client(client)
		$stderr.puts "Processing client request %p" % [client]
		
		begin
			parser = HttpParser.new
			params = HttpParams.new
			request = nil
			data = client.readpartial(Const::CHUNK_SIZE)
			nparsed = 0

			# Assumption: nparsed will always be less since data will get filled with more
			# after each parsing.  If it doesn't get more then there was a problem
			# with the read operation on the client socket.  Effect is to stop processing when the
			# socket can't fill the buffer for further parsing.
			while nparsed < data.length
				nparsed = parser.execute(params, data, nparsed)

				if parser.finished?
					if not params[Const::REQUEST_PATH]
						# it might be a dumbass full host request header
						uri = URI.parse(params[Const::REQUEST_URI])
						params[Const::REQUEST_PATH] = uri.request_uri
					end

					raise "No REQUEST PATH" if not params[Const::REQUEST_PATH]

					script_name, path_info, handlers = @classifier.resolve(params[Const::REQUEST_PATH])

					if handlers
						params[Const::PATH_INFO] = path_info
						params[Const::SCRIPT_NAME] = script_name
						params[Const::REMOTE_ADDR] = params[Const::HTTP_X_FORWARDED_FOR] || client.peeraddr.last

						# select handlers that want more detailed request notification
						notifiers = handlers.select { |h| h.request_notify }
						request = HttpRequest.new(params, client, notifiers)

						# in the case of large file uploads the user could close the socket, so skip those requests
						break if request.body == nil  # nil signals from HttpRequest::initialize that the request was aborted

						# request is good so far, continue processing the response
						response = HttpResponse.new(client)

						dispatch_to_handlers(client, handlers, request, response)

						# And finally, if nobody closed the response off, we finalize it.
						unless response.done or client.closed? 
							response.finished
						end
					else
						# Didn't find it, return a stock 404 response.
						client.write(Const::ERROR_404_RESPONSE)
					end

					break #done
				else
					# Parser is not done, queue up more data to read and continue parsing
					chunk = client.readpartial(Const::CHUNK_SIZE)
					break if !chunk or chunk.length == 0  # read failed, stop processing

					data << chunk
					if data.length >= Const::MAX_HEADER
						raise HttpParserError.new("HEADER is longer than allowed, aborting client early.")
					end
				end
			end
		rescue EOFError,Errno::ECONNRESET,Errno::EPIPE,Errno::EINVAL,Errno::EBADF
			client.close rescue Object
		rescue HttpParserError
			if $mongrel_debug_client
				STDERR.puts "#{Time.now}: BAD CLIENT (#{params[Const::HTTP_X_FORWARDED_FOR] || client.peeraddr.last}): #$!"
				STDERR.puts "#{Time.now}: REQUEST DATA: #{data.inspect}\n---\nPARAMS: #{params.inspect}\n---\n"
			end
		rescue Errno::EMFILE
			reap_dead_workers('too many files')
		rescue Object
			STDERR.puts "#{Time.now}: ERROR: #$!"
			STDERR.puts $!.backtrace.join("\n") if $mongrel_debug_client
		ensure
			client.close rescue Object
			request.body.delete if request and request.body.class == Tempfile
		end
	end

	# Process each handler in registered order until we run out or one finalizes the 
	# response.
	def dispatch_to_handlers(client, handlers, request, response)
		handlers.each do |handler|
			handler.process(request, response)
			return if response.done or client.closed?
		end
	end
end
####################################################################################
###  END MONKEY EEK EEEK EEEEEEEEEEK
####################################################################################

# vim: set nosta noet ts=4 sw=4:
