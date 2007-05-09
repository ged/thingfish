#!/usr/bin/env ruby

begin
	require 'thingfish/handler'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

class LocalTimeHandler < ThingFish::Handler

	### Send the local time to the requester in plain text
	def process( request, response )
		response.start( 200, true ) do |headers, out|
			headers['Content-type'] = 'text/plain'
			out.print( Time.now.to_s )
		end
	end

end
