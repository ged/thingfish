#!/usr/bin/ruby
#
# This file 
# includes various necessary modifications to libraries we depend on. It pains us to 
# do it, but sometimes you just gotta patch the monkey. 
#
# == Version
#
#  $Id$
#
# == Authors
# This file includes code written by other people
#
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#
# == Copyright
#
# Any and all patches included here are hereby given back to the author/s of the
# respective original projects without limitation.
# 
# 
# 

require 'rubygems'

gem 'mongrel', '>= 1.1.3'

require 'mongrel'
require 'uuidtools'
require 'thingfish/mixins'

### Add HTML output to the core Object
class Object
	include ThingFish::HtmlInspectableObject
end

### Add convenience methods to Numerics
class Numeric
	include ThingFish::NumericConstantMethods::Time,
	        ThingFish::NumericConstantMethods::Bytes
end


# Define an #== if none exists
class UUID

	### Only add an #== method if there's not already one defined
	unless instance_methods( false ).include?( "==" )
		
		### Return +true+ if the given +other_uuid+ is the same as the
		### receiver.
		def ==( other_uuid )
			other_uuid = self.class.parse( other_uuid.to_s ) unless
				other_uuid.is_a?( self.class )
			return (self <=> other_uuid).zero?
		rescue ArgumentError
			return false
		end
		alias_method :eql?, :==
	end
end


####################################################################################
###  BEGIN MONKEY EEK EEEK EEEEEEEEEEK
####################################################################################

### This is a patch to Mongrel's HTTP server class to break out the dispatch of 
### handlers from the main #process_client method, allowing subclasses to override
### just the dispatcher part instead of the whole thing.  We've submitted a 
### (badly-formatted -- sorry Zed!) patch back to Mongrel.
class Mongrel::HttpServer
	include Mongrel
	
	# Does the majority of the IO processing.  It has been written in Ruby using
	# about 7 different IO processing strategies and no matter how it's done 
	# the performance just does not improve.  It is currently carefully constructed
	# to make sure that it gets the best possible performance, but anyone who
	# thinks they can make it faster is more than welcome to take a crack at it.
	def process_client(client)
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

		              # From http://www.ietf.org/rfc/rfc3875 :
		              # "Script authors should be aware that the REMOTE_ADDR and REMOTE_HOST
		              #  meta-variables (see sections 4.1.8 and 4.1.9) may not identify the
		              #  ultimate source of the request.  They identify the client for the
		              #  immediate request to the server; that client may be a proxy, gateway,
		              #  or other intermediary acting on behalf of the actual source client."
						params[Const::REMOTE_ADDR] = client.peeraddr.last

						# select handlers that want more detailed request notification
						notifiers = handlers.select { |h| h.request_notify }
						request = HttpRequest.new(params, client, notifiers)

						# in the case of large file uploads the user could close the socket, so skip those requests
						break if request.body == nil  # nil signals from HttpRequest::initialize that the request was aborted

						# request is good so far, continue processing the response
						response = HttpResponse.new(client)

						### This replaces the handlers.each part of the original
						dispatch(client, handlers, request, response)
						#
						#
						### end of replaced code

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
				$stderr.puts "#{Time.now}: HTTP parse error, malformed request (#{params[Const::HTTP_X_FORWARDED_FOR] || client.peeraddr.last}): #{e.inspect}"
				$stderr.puts "#{Time.now}: REQUEST DATA: #{data.inspect}\n---\nPARAMS: #{params.inspect}\n---\n"
			end
		rescue Errno::EMFILE
			reap_dead_workers('too many files')
		rescue => err
			$stderr.puts "#{Time.now}: ERROR: #{err.message}"
			$stderr.puts err.backtrace.join("\n")
		ensure
			begin
				client.close
			rescue IOError
				# Already closed
			rescue => err
				$stderr.puts "#{Time.now}: Client error: #{err.inspect}"
				$stderr.puts err.backtrace.join("\n")
			end
			request.body.delete if request and request.body.class == Tempfile
		end
	end

	# Process each handler in registered order until we run out or one finalizes the 
	# response.
	def dispatch(client, handlers, request, response)
		handlers.each do |handler|
			handler.process(request, response)
			return if response.done or client.closed?
		end
	end
end
####################################################################################
###  END MONKEY EEK EEEK EEEEEEEEEEK
####################################################################################
