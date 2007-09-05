#!/usr/bin/ruby
# 
# ThingFish::Response -- a wrapper around a Mongrel::HttpResponse, providing
# a unified spot for current HTTP status, response headers, data to be
# returned to the client, and bindings to the responding handler methods.
# 
# == Synopsis
# 
#   require 'thingfish/response'
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


require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/constants'
require 'forwardable'

### Response wrapper class
class ThingFish::Response
	include ThingFish::Loggable,
	        ThingFish::Constants
	
	extend Forwardable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default HTTP status of new responses
	DEFAULT_STATUS = HTTP::NOT_FOUND


	### Create a new ThingFish::Response wrapped around the given
	### +mongrel_response+.
	### The specified +spooldir+ will be used for spooling uploaded files, 
	def initialize( mongrel_response )
		@mongrel_response = mongrel_response

		@headers  = ThingFish::Table.new
		@body     = nil
		@status   = nil
		@handlers = []
		@filters  = []
		
		self.reset
	end


	######
	public
	######

	# Methods that fall through to the Mongrel response object
	def_delegators :@mongrel_response, :write, :done, :done=
	
	# The original Mongrel::HttpResponse object
	attr_reader :mongrel_response

	# The response headers (a ThingFish::Table)
	attr_reader :headers

	# The response body
	attr_accessor :body
	
	# The HTTP status code
	attr_accessor :status

	# The ThingFish::Handlers which have participated in satisfying this request so far
	attr_reader :handlers

	# The ThingFish::Filters which will be given the opportunity to modify the
	# response
	attr_reader :filters


	### Returns true if the response is ready to be sent to the client.
	def handled?
		return @status != DEFAULT_STATUS
	end
	alias_method :is_handled?, :handled?


	### Clear any existing headers and body and restore them to their defaults
	def reset
		@headers.clear
		@headers[:server] = SERVER_SOFTWARE_DETAILS
		@status = DEFAULT_STATUS
		@body = ''
		
		return true
	end


	### Get the length of the body, either by calling its #length method if it has 
	### one, or using #seek and #tell if it implements those. If neither of those are
	### possible, an exception is raised.
	def get_content_length
		if @body.respond_to?( :length )
			return @body.length
		elsif @body.respond_to?( :seek ) && @body.respond_to?( :tell )
			starting_pos = @body.tell
			@body.seek( 0, IO::SEEK_END )
			length = @body.tell - starting_pos
			@body.seek( starting_pos, IO::SEEK_SET )
			
			return length
		else
			raise ThingFish::ResponseError,
				"No way to calculate the content length of the response (a %s)." %
				[ @body.class.name ]
		end
	end
	
end # ThingFish::Response

# vim: set nosta noet ts=4 sw=4:
