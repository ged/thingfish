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
#   # Set some more metadata (method style):
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
#   resource = client.fetch( uuid, :as => 'image/png' )
#
#   # Fetch a TIFF resource as either a JPEG or a PNG, preferring the former:  #TODO#
#   resource = client.fetch( uuid, :as => ['image/jpeg', 'image/png'] )
#
#   # Check to see if a UUID is a valid resource
#   client.has?( uuid ) # => true
#
#   
#   ### Deleting
#   
#   client.delete( uuid )
#   # -or-
#   client.delete( resource )
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
require 'tmpdir'

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


	# Accept header sent with HTTP requests: prefer directly-marshalled Ruby
	# objects, but fall back to YAML
	ACCEPT_HEADER = "%s;version=%d.%d, text/x-yaml;q=0.9" %
		[ RUBY_MARSHALLED_MIMETYPE, Marshal::MAJOR_VERSION, Marshal::MINOR_VERSION ]

	# The content of the User-Agent header send with all requests
	USER_AGENT_HEADER = "%s/%s.%d" %
		[ self.name.downcase.gsub(/\W+/, '-'), ThingFish::VERSION, SVNRev[/\d+/] ]

	# Maximum size of a resource response that's kept in-memory. Anything larger
	# gets buffered to a tempfile.
	MAX_INMEMORY_RESPONSE_SIZE = 128.kilobytes 


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ThingFish client object which will interact with the
	### server at the specified +endpoint+, which can be either the hostane,
	### the IP address, or the URI of the server. Also set any options
	### specified as attributes on the client.
	def initialize( endpoint=DEFAULT_HOST, options={} )
		@server_info = nil
		@profile     = nil
		
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
	
	# Profiling boolean
	attr_accessor :profile

	# Delegate some methods to the URI
	def_delegators :@uri,
		:scheme,  :userinfo,  :user,  :password,  :host,  :port,
		:scheme=, :userinfo=, :user=, :password=, :host=, :port=


	### Return a stringified version of the client's URI with the password elided.
	def politeuri
		newuri = self.uri.dup
		newuri.password = newuri.password.gsub(/./, 'x') if newuri.password
		return newuri
	end
	

	### Return a human-readable 
	def inspect
		"<%s:0x%08x %s>" % [ self.class.name, self.object_id * 2, self.politeuri ]
	end


	#################################################################
	###	I N T R O S P E C T I O N   F U N C T I O N S
	#################################################################

	### Returns a Hash of information about the server
	def server_info
		unless @server_info
			self.log.info "Fetching server info from %s" % [ self.politeuri ]
			request = Net::HTTP::Get.new( '/' )
			request['Accept'] = ACCEPT_HEADER

			send_request( request ) do |response|
				@server_info = self.extract_response_body( response )
			end
			
			self.log.debug "Server info is: %p" % [ @server_info ]
		end
		
		return @server_info
	end
	

	### Return the server URI for the given +handler+ (as mapped in the #server_info :handlers 
	### hash)
	def server_uri( handler )
		info = self.server_info
		path = info['handlers'][ handler.to_s ] or
			raise ThingFish::ClientError, "server does not support the '#{handler}' service"
		
		self.log.debug "Server URI for the '%s' service is: %s" %
			[ handler, self.uri + path.first ]
		
		return self.uri + path.first.chomp('/')
	end
	

	#################################################################
	###	F E T C H   F U N C T I O N S
	#################################################################

	### Fetch the resource with the given +uuid+ as a ThingFish::Resource object.
	def fetch( uuid )
		metadata = self.fetch_metadata( uuid ) or return nil
		return ThingFish::Resource.new( nil, self, uuid, metadata )
	end


	### Fetch the metadata for the resource identified by the given +uuid+ and
	### return it as a Hash.
	def fetch_metadata( uuid )
		metadata = nil

		fetchuri = self.server_uri( :simplemetadata )
		fetchuri.path += "/#{uuid}"

		self.log.info "Fetching metadata for a resource object from: %s" % [ fetchuri ]
		request = Net::HTTP::Get.new( fetchuri.path )
		request['Accept'] = ACCEPT_HEADER
			
		self.send_request( request ) do |response|
			self.log.debug "Creating a ThingFish::Resource from %p" % [response]
			metadata = self.extract_response_body( response )
		end

		self.log.debug { "Returning resource: %p" % [metadata] }
		return metadata
	end


	### Fetch the raw data for the specified +uuid+ from the ThingFish server and
	### return it as an IO object.
	def fetch_data( uuid )
		fetchuri = self.server_uri( :default )
		fetchuri.path += "#{uuid}"

		path = fetchuri.path.squeeze( '/' ) # Eliminate '//'
		self.log.info "Fetching resource data from: %s" % [ fetchuri ]
		request = Net::HTTP::Get.new( path )
		request['Accept'] = '*/*'
		
		io = self.send_request( request ) do |response|
			self.create_io_from_response( uuid, response )
		end

		return io
	end
	

	### Check the validity of a uuid by doing a HEAD, and return
	### a boolean.
	def has?( uuid )
		fetchuri = self.server_uri( 'simplemetadata' )
		fetchuri.path += "/#{uuid}"
		resource = nil

		request = Net::HTTP::Head.new( fetchuri.path )
			
		res = self.send_request( request )
		return res.is_a?( Net::HTTPSuccess )
	end
	
	
	### Store the given +resource+ (which can be a ThingFish::Resource, a String 
	### containing resource data, or an IO from which resource data can be read) on
	### the server. The optional +metadata+ hash can be used to set metadata values
	### for the resource.
	def store( resource )
		resource = self.store_data( resource )
		self.store_metadata( resource )

		return resource
	end
	
	
	### Store just the data part of the given +resource+ on the server, creating a new 
	### ThingFish::Resource if +resource+ doesn't already have a UUID.
	def store_data( resource )
		resource = ThingFish::Resource.new( resource, self ) unless
			resource.is_a?( ThingFish::Resource )

		# If it's an existing resource (i.e., has a UUID), update it, otherwise
		# create it
		request = nil
		uri = self.server_uri( 'default' )
		if uuid = resource.uuid
			self.log.debug "Creating an update PUT request for resource %p" % [ uuid ]
			request = Net::HTTP::Put.new( uri.path + uuid )
		else
			self.log.debug "Creating a creation POST request for a new resource" 
			request = Net::HTTP::Post.new( uri.path )
		end

        self.log.debug "Setting request %p body stream to %p" % [ request, resource.io ]

		request.body_stream = resource.io
		request['Content-Length'] = resource.extent
		request['Content-Type'] = resource.format
		request['Content-Disposition'] = 'attachment;filename="%s"' %
		 	[ resource.title ] if resource.title
		request['Accept'] = ACCEPT_HEADER

		self.send_request( request ) do |response|

			# Set the UUID if it wasn't already and merge metadata returned in the response 
			# without clobbering any existing values
			resource.uuid = response['Location'][UUID_REGEXP] unless uuid
			metadata = self.extract_response_body( response )
			resource.metadata = metadata.merge( resource.metadata )
		end

		return resource
	end


	### Store the metadata for the given +resource+ on the server. The +resource+ must already
	### have a UUID or an exception will be raised.
	def store_metadata( resource )
		uuid = resource.uuid or 
			raise ThingFish::ClientError,
			"cannot store metadata for an unsaved resource."

		uri = self.server_uri( 'simplemetadata' )
		self.log.debug "Creating an update PUT request for resource %p" % [ uuid ]
		request = Net::HTTP::Put.new( uri.path + '/' + uuid )

		data = Marshal.dump( resource.metadata )
		request.body = data
		request['Content-Length'] = data.length
		request['Content-Type'] = RUBY_MARSHALLED_MIMETYPE
		request['Accept'] = ACCEPT_HEADER

		self.send_request( request ) do |response|
			metadata = self.extract_response_body( response ) or
				raise ThingFish::ClientError, "no body in the update response"
			resource.metadata = metadata
		end

		return resource
	end
	


	### Delete the resource that corresponds to a given uuid on the server. The
	### +argument+ can be either a UUID string or an object that
	### responds_to? #uuid.
	def delete( argument )
		argument = argument.uuid if argument.respond_to?( :uuid )
		uuid = UUID.parse( argument )

		uri = self.server_uri( :default )
		request = Net::HTTP::Delete.new( uri.path + "#{uuid}" )
		
		send_request( request ) do |response|
			response.error! unless response.is_a?( Net::HTTPSuccess )
		end
		
		return true
	end


	### Search for resources based on the +criteria+ hash, which should consist
	### of metadata keys and the desired matching values.
	def find( criteria={} )
		uri = self.server_uri( :simplesearch )
		query_args = make_query_args( criteria )
		request = Net::HTTP::Get.new( uri.path + query_args )
		resources = []
	
		request['Accept'] = ACCEPT_HEADER	
		send_request( request ) do |response|
			response.error! unless response.is_a?( Net::HTTPSuccess )
			uuids = self.extract_response_body( response )
			uuids.each do |uuid|
				resources << ThingFish::Resource.new( nil, self, uuid )
			end
		end
		
		return resources
	end
	
	
	#########
	protected
	#########

	### Extract the serialized object in the given +response+'s entity body and return it.
	def extract_response_body( response )
		
		case response['Content-Type']			
		when /#{RUBY_MARSHALLED_MIMETYPE}/i
			self.log.debug "Unmarshalling a marshalled-ruby-object response body."
            return Marshal.load( response.body )

		when %r{text/x-yaml}i
			self.log.debug "Deserializing a YAML-encoded response body."
			return YAML.load( response.body )

		else
			self.log.warn "Response body was %p instead of serialized Ruby or YAML" %
				[ response['Content-Type'] ]
			return response.body
		end

	end
	
	
	### Read the data from the given +response+ and either return an IO (if it's
	### larger than MAX_INMEMORY_RESPONSE_SIZE), or an in-memory StringIO.
	def create_io_from_response( uuid, response )
		len = Integer( response['Content-length'] )
		self.log.debug "Content length is: %p" % [ len ]

		if len > MAX_INMEMORY_RESPONSE_SIZE
			self.log.debug "...buffering to disk"
			file = Pathname.new( Dir.tmpdir ) + "tf-#{uuid}.data.0"
			fh = nil
			
			begin
				fh = file.open( File::CREAT|File::RDWR|File::EXCL, 0600 )
			rescue Errno::EEXIST
				file = file.sub( /\.(\d+)$/ ) { '.' + $1.succ }
				retry
			end

			file.delete
			response.read_body do |chunk|
				fh.write( chunk )
			end
			fh.rewind
			
			return fh
		else
			self.log.debug "...'buffering' to memory"
			return StringIO.new( response.body )
		end
	end
	
	
	### Send the given HTTP::Request to the host and port specified by +uri+ (a URI 
	### object). The +limit+ specifies how many redirects will be followed before giving 
	### up.
	def send_request( req, limit=10 )
		req['User-Agent'] = USER_AGENT_HEADER

		self.log.debug "Request: " + dump_request_object( req )

		if @profile
			req.path << ( req.path =~ /\?/ ? "&#{PROFILING_ARG}=true" : "?#{PROFILING_ARG}=true" )
		end
		
		Net::HTTP.start( uri.host, uri.port ) do |conn|
			conn.request( req ) do |response|
				return response unless block_given?
				
				self.log.debug "Response: " + dump_response_object( response )

				case response
				when Net::HTTPOK, Net::HTTPCreated
					return yield( response )

				when Net::HTTPSuccess
					raise ThingFish::ClientError,
						"Unexpected %d response to %s" % [ response.status, req.to_s ]

				else
					response.error!
				end
			end
		end
	end


	### Given a +hash+, build and return a query argument string.
	def make_query_args( hash )
		query_args = hash.collect do |k,v|
			"%s=%s" % [ URI.escape(k.to_s), URI.escape(v.to_s) ]
		end
		
		return '?' + query_args.sort.join(';')
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

