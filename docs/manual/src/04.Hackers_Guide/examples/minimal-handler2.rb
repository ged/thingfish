
require 'thingfish/constants'
require 'thingfish/handler'

class TimeHandler < ThingFish::Handler
	include ThingFish::Constants::HTTP

	### Send the local time to the requester in plain text.
	def handle_get_request( request, response )

		time = Time.now
		uri  = request.path_info

		begin
			case uri
			when '', '/'
				response.body   = time.to_s
				response.status = OK
			else
				time_method     = uri.sub( %r{^/}, '')
				response.body   = time.send( time_method.to_sym ).to_s
				response.status = OK
			end
		rescue NoMethodError
			# fall through to 404
		end
	end
end
