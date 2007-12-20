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
# 			- formupload:
# 				uris: /upload
# 				resource_dir: plugins/thingfish-formuploadhandler/resources
# 
# == Config Keys
# 
# 	[+bufsize+]
# 		The size of the buffer to use when reading incoming data (in bytes).	
# 		Defaults to ThingFish::FormUploadHandler::DEFAULT_BUFSIZE
# 
# 	[+spooldir+]
# 		The directory in which to store uploaded resources before they are injected
# 		into the filestore.
# 		Defaults to ThingFish::FormUploadHandler::DEFAULT_SPOOLDIR
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

class ThingFish::FormUploadHandler < ThingFish::Handler

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


	### HTML generation using the HTML filter.
	def make_html_content( files, request, response )
		uri = request.uri.path

		response.data[:title] = 'upload'
		response.data[:head]  = %Q{
	<script src="#{uri}/js/jquery.MultiFile.js" type="text/javascript" charset="utf-8"></script>
		}
		
		formtemplate = self.get_erb_resource( 'uploadform.rhtml' )
		uploadform = formtemplate.result( binding() )

		# uploadform is rendered in-place in this template
		content = self.get_erb_resource( 'upload.rhtml' )
		return content.result( binding() )
	end


	#########
	protected
	#########

	### Handle a GET request
	def handle_get_request( request, response )
		return unless request.path_info == ''
		response.data[:tagline] = 'Feed me.'
		response.headers[:content_type] = RUBY_MIMETYPE
		response.status = HTTP::OK
	end


	### Handle a POST request
	def handle_post_request( request, response )
		return unless request.path_info == ''

		self.log.debug "Handling POSTed upload/s"
		response.data[:tagline] = 'Yum!'

		files = []
		request.each_body do |body, metadata|
			body.open  # reopen filehandle for store_io
			uuid = self.daemon.store_resource( body, metadata )
			metadata[:uuid] = uuid
			files << [ uuid, metadata ]
		end

		# Return success with links to new files
		response.headers[:content_type] = RUBY_MIMETYPE
		response.status = HTTP::OK
		response.body   = files
	end

end # class ThingFish::FormUploadHandler

# vim: set nosta noet ts=4 sw=4:
