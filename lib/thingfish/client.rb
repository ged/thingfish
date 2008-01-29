#!/usr/bin/ruby
# 
# ThingFish::Client -- The Ruby ThingFish client library
# 
# == Synopsis
# 
#   require 'thingfish/client'
#
#   # Connect to the ThingFish server
#   client = ThingFish::Client.new( server, username, password )
#
#   
#   ### Storing
#
#   # Create the entry then save it
#   resource = ThingFish::Resource.new( File.open("mahlonblob.dxf") )
#   resource.format = 'image/x-dxf'
#   resource = client.store( resource )
#   # =>  #<ThingFish::Resource:0x142b3b8 UUID:fde68574-fd73-11db-a31e-6f1a83274382>
#
#   # Or do it all in one line   #TODO#
#   client.store( File.open("woowoooo.wav"), :author => 'Bubb Rubb' )
#   resource = client.store( File.open("mahlonblob.dxf"), :format => 'image/x-dxf' )
#   # =>  #<ThingFish::Resource:0xa5a5be UUID:7602813e-dc77-11db-837f-0017f2004c5e>
#   
#   # Set some more metadata (method style):    #TODO#
#   resource.owner = 'mahlon'
#   resource.description = "3D model used to test the new All Open Source pipeline"
#   # ...or hash style:
#   resource[:keywords] = "3d, model, mahlon"
#   resource[:date_created] = Date.today
#
#   # Now save the resource back to the server it was fetched from
#   resource.save
#
#	# Discard changes in favor of server side data    #TODO#
#	resource.revert!
#
#
#   ### Fetching
#   
#   # Fetch a resource by UUID
#   uuid = '7602813e-dc77-11db-837f-0017f2004c5e'
#   resource = client.fetch( uuid )
#   # =>  #<ThingFish::Resource:0xa5a5be UUID:7602813e-dc77-11db-837f-0017f2004c5e>
#   
#   # Use the data
#   resource.data # => (DXF data)
#
#   # Fetch a GIF resource as a PNG if the server supports that transformation:  #TODO#
#   resource = client.fetch( uuid, :accept => ['image/png'] )
#
#   # Fetch a TIFF resource as either a JPEG or a PNG, preferring the former:  #TODO#
#   resource = client.fetch( uuid, :accept => ['image/jpeg', 'image/png;q=0.5'] )
#
#   # Check to see if a UUID is a valid resource
#   client.has?( uuid ) # => true
#
#
#   ### Searching
# 
#   # ...or search for resources whose metadata match search criteria. Find
#   # all DXF objects owned by Mahlon:   #TODO#
#   uuids = client.find( :format => 'image/x-dxf', :owner => 'mahlon'  )
#   # =>  [ '7602813e-dc77-11db-837f-0017f2004c5e', ... ]
#
#
#   ### Streaming data
#
#	# Export to an IO object for buffered write   #TODO#
#	resource.export( socket )
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

require 'net/http'
require 'net/https'
require 'uri'
require 'forwardable'
require 'date'
require 'set'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/mixins'
require 'thingfish/resource'


### The thingfish client library
class ThingFish::Client
	include ThingFish::Constants::Patterns,
		ThingFish::Constants,
		ThingFish::Loggable

	extend Forwardable

	# Assure that 1.2 features present in net/http
	Net::HTTP.version_1_2
	
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ThingFish client object which will interact with the
	### server at the specified +endpoint+, which can be either the hostane,
	### the IP address, or the URI of the server. Also set any options
	### specified as attributes on the client.
	def initialize( endpoint=DEFAULT_HOST, options={} )
		
		# If it contains a '/', assume it's a URI
		if endpoint =~ %r{/}
			@uri = URI.parse( endpoint )
		elsif endpoint.is_a?( URI )
			@uri = endpoint.dup
		else
			@uri = URI.parse( "http://#{endpoint}:#{DEFAULT_PORT}/" )
		end

		# Normalize the URI's path
		@uri.path = '/' if @uri.path.empty?

		# Process the options hash if any
		pass = options.delete('password') || options.delete( :password )
		options.each do |meth, value|
			self.send( "#{meth}=", value )
		end
		self.password = pass if pass
	end


	######
	public
	######

	# The URI of the API endpoint
	attr_reader :uri
	

	# Delegate some methods to the URI
	def_delegators :@uri,
		:scheme,  :userinfo,  :user,  :password,  :host,  :port,
		:scheme=, :userinfo=, :user=, :password=, :host=, :port=


	### Return a human-readable 
	def inspect
		politeuri = self.uri.dup
		politeuri.password = politeuri.password.gsub(/./, 'x') if politeuri.password
		"<%s:0x%08x %s>" % [ self.class.name, self.object_id * 2, politeuri ]
	end


	#################################################################
	###	I N T R O S P E C T I O N   F U N C T I O N S
	#################################################################

	### Returns a Hash of information about the server
	def server_info
		request = Net::HTTP::Get.new( '/' )
		request['Accept'] = RUBY_MARSHALLED_MIMETYPE
		
		response = send_request( request )
		
		return Marshal.load( response.body )
	end
	

	#################################################################
	###	F E T C H   F U N C T I O N S
	#################################################################

	### Fetch the resource with the given +uuid+ as a ThingFish::Resource object.
	def fetch( uuid, head=nil )
		fetchuri = self.uri + uuid.to_s

		request = head ?
			Net::HTTP::Head.new( fetchuri.path ) :
			Net::HTTP::Get.new(  fetchuri.path )
			
		request['Accept'] = '*/*'
		resource = nil

		send_request( request ) do |response|
			case response
			when Net::HTTPOK
									
				# :TODO: Set metadata for the resource from the response (multipart?)
				self.log.debug "Creating a ThingFish::Resource from %p" % [response]
				resource = ThingFish::Resource.from_http_response( response, :uuid => uuid )
				resource.client = self

			# TODO: Handle redirect/auth/etc.
			# when Net::HTTPRedirect
			else
				resource = nil
			end
			
			response
		end

		self.log.debug "Returning resource: %p" % [resource]
		return resource
	end


	### Check the validity of a uuid by doing a HEAD, and return
	### a boolean.
	def has?( uuid )
		return self.fetch( uuid, true ) ? true : false
	end
	
	
	### Store the given +resource+ (which can be a ThingFish::Resource, a String 
	### containing resource data, or an IO from which resource data can be read) on
	### the server. The optional +metadata+ hash can be used to set metadata values
	### for the resource.
	def store( resource, metadata={} )
		resource = ThingFish::Resource.new( resource, metadata ) unless
			resource.is_a?( ThingFish::Resource )

		# If it's an existing resource (i.e., has a UUID), update it, otherwise
		# create it
		request = nil
		if uuid = resource.uuid
			self.log.debug "Creating an update PUT request for resource %p" % [ uuid ]
			request = Net::HTTP::Put.new( @uri.path + uuid )
		else
			self.log.debug "Creating a creation POST request for a new resource" 
			request = Net::HTTP::Post.new( @uri.path )
		end

        self.log.debug "Setting request %p body stream to %p" % [ request, resource.io ]
		request.body_stream = resource.io
		request['Content-Length']      = resource.extent
		request['Content-Type']        = resource.format
		request['Content-Disposition'] = 'attachment;filename="%s"' %
		 	[ resource.title ] if resource.title

		self.send_request( request ) do |response|
			case response
			when Net::HTTPSuccess
									
				# :TODO: Set metadata for the resource from the response (multipart?)
				self.log.debug "Updating resource %p from %p" % [ resource, response ]
				resource.set_attributes_from_http_response( response )
				return true

			# TODO: Handle redirect/auth/etc.
			# when Net::HTTPRedirect
			else
				response.error!
			end
		end

		return resource
	end


	#########
	protected
	#########

	### Send the given HTTP::Request to the host and port specified by +uri+ (a URI 
	### object). The +limit+ specifies how many redirects will be followed before giving 
	### up.
	def send_request( req, limit=10, &block )
		self.log.debug "Request: " + dump_request_object( req )
		
		response = Net::HTTP.start( uri.host, uri.port ) do |conn|
			conn.request( req, &block )
		end
	
		self.log.debug "Response: " + dump_response_object( response )
		return response
	end


	### Return the request object as a string suitable for debugging
	def dump_request_object( request )
		buf = "#{request.method} #{request.path} HTTP/#{Net::HTTP::HTTPVersion}\r\n"
		request.each_capitalized do |k,v|
			buf << "#{k}: #{v}\r\n"
		end
		buf << "\r\n"

		return buf
	end


	### Return the response object as a string suitable for debugging
	def dump_response_object( response )
		buf = "#{response.code} #{response.message}\r\n"
		response.each_capitalized do |k,v|
			buf << "#{k}: #{v}\r\n"
		end
		buf << "\r\n"
		
		return buf
	end



end # class ThingFish::Client

# vim: set nosta noet ts=4 sw=4:

