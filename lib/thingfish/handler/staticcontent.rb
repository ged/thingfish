#!/usr/bin/ruby
#
# The static resources handler -- serves static content from a directory. This is the
# handler that's installed by the ThingFish::StaticResourcesHandler mixin ahead of
# the including class in the URIspace.
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

require 'pp'
require 'thingfish'
require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'


### The default top-level handler for the thingfish daemon
class ThingFish::StaticContentHandler < ThingFish::Handler

	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		ThingFish::Loggable


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default content type
	DEFAULT_CONTENT_TYPE = 'application/octet-stream'
	
	# The name of an index file to look for should the request specify a directory
	DEFAULT_INDEX_FILE = 'index.html'


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new StaticContentHandler that will serve static content under the 
	### given +basedir+ (a Pathname object).
	def initialize( basedir )
		@basedir = basedir.expand_path
	end
	

	######
	public
	######

	# The directory this handler should use as its base
	# :TODO: Document use-case of changing this on the fly based on Host: header.
	attr_accessor :basedir
	

	### Handle a GET request
	def handle_get_request( request, response )

		path = request.path_info
		file = self.get_safe_path( path ) or return

		# Support index files.
		file = file + DEFAULT_INDEX_FILE if file.directory?
		
		unless file.exist?
			self.log.error "Request for non-existant resource: %p" % [ path ]
			return
		end
		
		# Is the requested file a plain file?
		unless file.file?
			self.log.error "Request for %p: not a plain file" % [ path ]
			response.status = HTTP::FORBIDDEN
			response.body   = "Request for %p denied." % [ path ]
			return
		end

		# Do we have access to read it?
		unless file.readable?
			self.log.error "Request for %p: Permission denied" % [ path ]
			response.status = HTTP::FORBIDDEN
			response.body   = "Request for %p denied." % [ path ]
			return
		end

		# TODO: Add etag caching
		# Calculate caching data (lots of this stuff borrowed from Mongrel's 
		# DirHandler)
		# mtime = file.mtime
		# etag = Const::ETAG_FORMAT % [mtime.to_i, file.size, file.ino]
		# response.headers[:etag] = etag
		# response.headers[:]
		# 
		# if self.is_cacheable( request, file )
		# 	response.status = HTTP::NOT_MODIFIED
		# 	response.body = ''
		# 
		# 	response.headers[:etag] = 
		# 
		# 	return
		# end

		# Set Content-Type and Content-Length headers.
		extension = file.extname.downcase
		if MIMETYPE_MAP.key?( extension )
			response.headers[:content_type] = MIMETYPE_MAP[ extension ]
			self.log.debug {
				"Setting content-type to %p for %p" %
					[ MIMETYPE_MAP[extension], file.to_s ]
			}
		else
			self.log.warn "No MIME mapping for %p" % [ extension ]
			response.headers[:content_type] = DEFAULT_CONTENT_TYPE
		end
		response.headers[:content_length] = file.size
				
		response.status = HTTP::OK
		response.body = file.open('r')
	end


	#########
	protected
	#########

	### Given a +path+, try to map it to a file under the handler's base directory.  
	### Return a Pathname object to the requested file if valid, +nil+ if not.
	def get_safe_path( path )
		path.sub!( %r{^/}, '' )
		file = @basedir + path
				
		# Check for a path that points to a file outside of the directory this handler
		# is configured to serve from
		if file.relative_path_from( @basedir ).to_s =~ %r{\.\.}
			self.log.error "Request for file outside of static resource dir: %p" % [path]
			return nil
		end
		
		return file
	end
	

end # ThingFish::StaticContentHandler

# vim: set nosta noet ts=4 sw=4:
