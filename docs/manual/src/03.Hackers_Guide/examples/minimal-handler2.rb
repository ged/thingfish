
require 'thingfish/constants'
require 'thingfish/handler'

class TimeHandler < ThingFish::Handler
	include ThingFish::Constants

	### Send the local time to the requester in plain text.
	def handle_get_request( request, response )

		time = Time.now
		uri  = request.path_info

		case uri
		when '', '/'
			response.body = time.to_s
		when '/epoch'
			response.body = time.to_i
		when '/rfc822', '/rfc2822'
			response.body = time.rfc2822
		when '/xmlschema'
			response.body = time.xmlschema
		else
			return
		end

		response.headers[:content_type] = 'text/plain'
		response.status = HTTP::OK
	end
end
