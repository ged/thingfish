#!/usr/bin/ruby
=begin

Accept and unwrap multipart form uploads, as documented at
http://www.w3.org/Protocols/rfc1341/7_2_Multipart.html

== Synopsis

	# thingfish.conf
	#
	plugins:
		handlers:
			- upload:
				uris: /upload
				resource_dir: plugins/thingfish-uploadhandler/resources

== Config Keys

	[+bufsize+]
		The size of the buffer to use when reading incoming data (in bytes).	
		Defaults to ThingFish::UploadHandler::DEFAULT_BUFSIZE

	[+spooldir+]
		The directory in which to store uploaded resources before they are injected
		into the filestore.
		Defaults to ThingFish::UploadHandler::DEFAULT_SPOOLDIR

== Version

$Id$

== Authors

* Mahlon E. Smith <mahlon@laika.com>
* Michael Granger <mgranger@laika.com>

:include: LICENSE

--

Please see the file LICENSE in the 'docs' directory for licensing details.

=end

require 'thingfish'
require 'thingfish/handler'
require 'thingfish/constants'
require 'mongrel/handlers'
require 'strscan'
require 'forwardable'
require 'tempfile'
require 'uuidtools'
require 'e2mmap'

class ThingFish::UploadHandler < ThingFish::Handler
	require 'thingfish/multipartparser'

	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::StaticResourcesHandler,
	        ThingFish::ResourceLoader

	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new UploadHandler
	def initialize( options={} )
		@parser = ThingFish::MultipartMimeParser.new( options )
		super
	end


	######
	public
	######

	# Delegate some settings to the parser object
	def_delegators :@parser, :bufsize, :bufsize=, :spooldir, :spooldir=

	# The multipart parser the handler uses to extract uploaded data
	attr_accessor :parser
	

	### Process a upload request
	def process( request, response )
		super

		method = request.params['REQUEST_METHOD']

		case method
		when 'GET'
			self.handle_get_request( request, response )

		when 'POST'
			self.handle_post_request( request, response )

		else
			self.log.notice( "Refusing to handle a #{method} request" )
			response.start( HTTP::METHOD_NOT_ALLOWED, true ) do |headers, out|
				headers['Allow'] = 'GET, POST'
				out.write( "%s method not allowed." % method )
			end
		end
	end



	#########
	protected
	#########

	### Handle a GET request
	def handle_get_request( request, response )
		uri = request.params['REQUEST_URI']
		
		# Attempt to serve upload form
		content = self.get_erb_resource( 'upload.rhtml' )
		response.start( HTTP::OK, true ) do |headers, out|
			headers['Content-Type'] = 'text/html'
			out.write( content.result(binding()) )
		end
	rescue Exception => err
		self.log.error "Error: " + err.message
		self.log.debug err.backtrace.join( "\n" )
	end


	### Handle a POST request
	def handle_post_request( request, response )
		self.log.debug "Handling POSTed upload/s"
		uri          = request.params['REQUEST_URI']
		content_type = request.params['HTTP_CONTENT_TYPE'] || ''

		# attempt to verify content-type, and parse boundry string
		unless content_type =~ %r{(multipart/form-data).*boundary="?([^\";,]+)"?}
			self.log.error "Bad content type; expected multipart, got: %p" % [content_type]
			return response.start( HTTP::BAD_REQUEST, true ) do |headers, out|
				out.write( 'Unable to parse multipart/form-data or find boundary.' )
			end
		end
		mimetype, boundary = $1, $2
		self.log.debug "Parsing a %s document with boundary %p" % [mimetype, boundary]

		# unwrap multipart
		begin
			files, params = @parser.parse( request.body, boundary )
			self.log.debug "Parsed %d files and %d params (%p)" % 
				[files.length, params.length, params.keys]
		rescue ThingFish::RequestError => err
			return response.start( HTTP::BAD_REQUEST, true ) do |headers, out|
				out.write( err.message )
			end
		end

		# merge global metadata with file specific metadata
		# walk through parsed files, pass to thingfish meta and file stores
		files.each do |file, meta|
			meta.merge!( params )

			# store the file
			file.open  # reopen filehandle for store_io
			meta[:uuid] = self.store_resource( file, meta, request )
		end

		# Return success with links to new files
		content = self.get_erb_resource( 'upload.rhtml' )
		response.start( HTTP::CREATED, true ) do |headers, out|
			headers['Content-Type'] = 'text/html'
			out.write( content.result(binding()) )
		end
	rescue Exception => err
		self.log.error "Error: " + err.message
		self.log.debug err.backtrace.join( "\n" )
	end


	### Store the data in +file+ as a new resource, extracting default metadata from
	### +request+ and storing any metadata in +meta+.
	def store_resource( file, meta, request )
		uuid = UUID.timestamp_create
		checksum = @filestore.store_io( uuid, file )

		# Store some default metadata about the resource
		@metastore[ uuid ].checksum = checksum
		@metastore.extract_default_metadata( uuid, request )

		# Iterate over metadata hash, attach to file
		meta.each do |key, val|
			next if val.to_s.length.zero?
			mstore = @metastore[ uuid ]
			mstore.send( "#{key}=", val )
		end

		self.log.info "Created new resource %s (%s, %0.2f KB), checksum is %s" % [
			uuid,
			meta[ :format ],
			meta[ :extent ] / 1024.0,
			checksum
		  ]

		return uuid
	end

end # class ThingFish::UploadHandler

# vim: set nosta noet ts=4 sw=4:
