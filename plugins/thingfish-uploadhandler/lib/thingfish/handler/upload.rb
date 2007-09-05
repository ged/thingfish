#!/usr/bin/ruby
# 
# Accept and unwrap multipart form uploads, as documented at
# http://www.w3.org/Protocols/rfc1341/7_2_Multipart.html
# 
# == Synopsis
# 
# 	# thingfish.conf
# 	#
# 	plugins:
# 		handlers:
# 			- upload:
# 				uris: /upload
# 				resource_dir: plugins/thingfish-uploadhandler/resources
# 
# == Config Keys
# 
# 	[+bufsize+]
# 		The size of the buffer to use when reading incoming data (in bytes).	
# 		Defaults to ThingFish::UploadHandler::DEFAULT_BUFSIZE
# 
# 	[+spooldir+]
# 		The directory in which to store uploaded resources before they are injected
# 		into the filestore.
# 		Defaults to ThingFish::UploadHandler::DEFAULT_SPOOLDIR
# 
# == Version
# 
# $Id$
# 
# == Authors
# 
# * Mahlon E. Smith <mahlon@laika.com>
# * Michael Granger <mgranger@laika.com>
# 
# :include: LICENSE
# 
# --
# 
# Please see the file LICENSE in the 'docs' directory for licensing details.


require 'thingfish'
require 'thingfish/handler'
require 'thingfish/constants'
require 'thingfish/multipartmimeparser'
require 'strscan'
require 'forwardable'
require 'tempfile'
require 'uuidtools'

class ThingFish::UploadHandler < ThingFish::Handler

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
		@parser = ThingFish::MultipartMimeParser.new
		super
	end


	######
	public
	######

	# Delegate some settings to the parser object
	def_delegators :@parser, :bufsize, :bufsize=, :spooldir, :spooldir=

	# The multipart parser the handler uses to extract uploaded data
	attr_accessor :parser
	

	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
		return tmpl.result( binding() )
	end


	#########
	protected
	#########

	### Handle a GET request
	def handle_get_request( request, response )
		return unless request.path_info == ''
		
		# Attempt to serve upload form
		content = self.get_erb_resource( 'upload.rhtml' )
		response.headers[ :content_type ] = 'text/html'
		response.body = content.result( binding() )
		response.status = HTTP::OK
	end


	### Handle a POST request
	def handle_post_request( request, response )
		return unless request.path_info == ''

		self.log.debug "Handling POSTed upload/s"

		# Parse the incoming request.
		files, params = request.parse_multipart_body
		self.log.debug "Parsed %d files and %d params (%p)" % 
			[files.length, params.length, params.keys]
	
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
		response.status = HTTP::OK
		response.headers[ :content_type ] = 'text/html'
		response.body = content.result( binding() )
	end


	### Store the data in +file+ as a new resource, extracting default metadata from
	### +request+ and storing any metadata in +meta+.
	def store_resource( file, meta, request )
		uuid = UUID.timestamp_create
		self.log.debug "Storing %p as %p" % [ file, uuid ]
		checksum = @filestore.store_io( uuid, file )
		file.unlink

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
