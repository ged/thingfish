#!/usr/bin/ruby
#
# inspect mailing list messages as parsed by the RFC 2822 filter.
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
#		- mailinglists:
#           uris: /ml
# 
# == Version
#
#  $Id$
#
# == Authors
#
# * Ben Bleything <bbleything@laika.com>
# * Michael Granger <mgranger@laika.com>
# * Jeremiah Jordan <jjordan@laika.com>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

begin
	require 'pp'
	require 'rbconfig'
	require 'pathname'
	require 'thingfish/mixins'
	require 'thingfish/handler'
	require 'thingfish/constants'
	require 'thingfish/exceptions'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### A mailinglists handler for ThingFish
class ThingFish::MailinglistsHandler < ThingFish::Handler
	include ThingFish::Loggable,
		ThingFish::Constants,
		ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Handler API: handle a GET request with an inspection page.
	def handle_get_request( request, response )
		case request.path_info
			
		when '/', ''
			# return an Array of mailing lists we know about?
			self.handle_get_root_request( request, response )
	
		when %r{^/(\w+)$}
			# return a Hash of mailing list details
			self.handle_get_list_name_request( request, response )
			
		when %r{^/(\w+)/count$}
			list_name = $1

			# return count of messages in this list
			self.handle_get_list_message_count_request( request, response, list_name )

		when %r{^/(\w+)/last_post_date$}
			list_name = $1

			# return date object representing last post date
			self.handle_get_list_last_post_date_request( request, response, list_name )

		else
			self.log.error "Unable to handle mailing list GET request: %p" % 
				[ request.path_info ]
			return
		end
	end
	
	
	### Query the metastore for all mailing list names and return those as
	### an array
	def handle_get_root_request( request, response )
		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = @metastore.get_all_property_values( 'list_name' )
	end
	
	
	### Count the messages in the archive for a given list name
	def handle_get_list_message_count_request( request, response, list_name )
		uuids = @metastore.find_exact_uuids( 'list_name' => list_name )
		
		if uuids.empty?
			response.status = HTTP::NOT_FOUND
			return
		else
			response.status = HTTP::OK
			response.content_type = RUBY_MIMETYPE
			response.body = uuids.size
		end
	end


	### Return the date of the last post to the list with the specified 
	### +list_name+.
	def handle_get_list_last_post_date_request( request, response, list_name )
		uuids = @metastore.find_exact_uuids( 'list_name' => list_name )
		if uuids.empty?
			response.status = HTTP::NOT_FOUND
			return
		end
		
		last = uuids.collect {|uuid| Date.parse(@metastore.get_property(uuid, :rfc822_date)) }.max
		
		response.status = HTTP::OK
		response.content_type = RUBY_MIMETYPE
		response.body = last
	end

end # class ThingFish::MailinglistsHandler

# vim: set nosta noet ts=4 sw=4:
