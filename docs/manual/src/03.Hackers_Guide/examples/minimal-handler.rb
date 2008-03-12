
require 'thingfish/constants'
require 'thingfish/handler'

class TimeHandler < ThingFish::Handler
	include ThingFish::Constants

	### Send the local time to the requester in plain text.
	def handle_get_request( request, response )
		response.body   = Time.now.to_s
		response.headers[:content_type] = 'text/plain'
		response.status = HTTP::OK
	end
end

