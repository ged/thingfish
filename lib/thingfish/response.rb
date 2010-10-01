#!/usr/bin/env ruby

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/constants'

#
# ThingFish::Response -- provide a unified spot for current HTTP status,
# response headers, and data to be returned to the client.
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
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::Response
	include ThingFish::Loggable,
	        ThingFish::Constants,
			ThingFish::HtmlInspectableObject


	### Create a new ThingFish::Response.
	def initialize( http_version, config )
		@http_version = http_version
		@config = config

		@headers  = ThingFish::Table.new
		@data     = ThingFish::Table.new
		@body     = nil
		@status   = nil
		@handlers = []
		@filters  = []

		self.reset
	end


	######
	public
	######

	# The HTTP version of the response
	attr_reader :http_version
	
	# The response headers (a ThingFish::Table)
	attr_reader :headers

	# The response body
	attr_accessor :body

	# The HTTP status code
	attr_accessor :status

	# The ThingFish::Handlers which have participated in satisfying this request so far
	attr_reader :handlers

	# A scratch-space area for passing data between handlers and filters
	attr_reader :data

	# The ThingFish::Filters which will be given the opportunity to modify the
	# response
	attr_reader :filters


	### Send the response status to the client
	def status_line
		self.log.warn "Building status line for unset status" if self.status.nil?
		return "HTTP/%1.1f %03d %s" % [
			self.http_version,
			self.status,
			HTTP::STATUS_NAME[self.status]
		]
	end


	### Returns true if the response is ready to be sent to the client.
	def handled?
		return ! @status.nil?
	end
	alias_method :is_handled?, :handled?


	### Return the numeric category of the response's status code (1-5)
	def status_category
		return 0 if self.status.nil?
		return (self.status / 100).ceil
	end


	### Return true if response is in the 1XX range
	def status_is_informational?
		return self.status_category == 1
	end

	### Return true if response is in the 2XX range
	def status_is_successful?
		return self.status_category == 2
	end


	### Return true if response is in the 3XX range
	def status_is_redirect?
		return self.status_category == 3
	end


	### Return true if response is in the 4XX range
	def status_is_clienterror?
		return self.status_category == 4
	end


	### Return true if response is in the 5XX range
	def status_is_servererror?
		return self.status_category == 5
	end


	### Return the current response Content-Type.
	def content_type
		return self.headers[ :content_type ]
	end


	### Set the current response Content-Type.
	def content_type=( type )
		return self.headers[ :content_type ] = type
	end


	### Clear any existing headers and body and restore them to their defaults
	def reset
		@headers.clear
		@headers[:server] = SERVER_SOFTWARE_DETAILS
		@status = nil
		@body = ''

		return true
	end

	
	### Return the current response header as a valid HTTP string.
	def header_data
		self.headers[:date] ||= Time.now.httpdate
		self.headers[:content_length] ||= self.get_content_length
		
		return self.headers.to_s
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


	### Set the Connection header to allow pipelined HTTP.
	def keepalive=( value )
		self.headers[:connection] = value ? 'keep-alive' : 'close'
	end
	alias_method :pipelining_enabled=, :keepalive=


	### Returns +true+ if the response has pipelining enabled.
	def keepalive?
		ka_header = self.headers[:connection]
		return !ka_header.nil? && ka_header =~ /keep-alive/i
		return false
	end
	alias_method :pipelining_enabled?, :keepalive?
	
	
end # ThingFish::Response

# vim: set nosta noet ts=4 sw=4:
