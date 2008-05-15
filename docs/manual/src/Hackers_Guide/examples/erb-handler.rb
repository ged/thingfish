require 'thingfish/constants'
require 'thingfish/handler'
require 'thingfish/mixins'

class TimeHandler < ThingFish::Handler
	include ThingFish::Constants,
		ThingFish::ResourceLoader

	### Send the local time to the requester in plain text.
	def handle_get_request( request, response )

		time = Time.now
		uri  = request.path_info
		template = self.get_erb_resource( "timehandler.rhtml" )
		title = "TimeServer 3000"
		timestring = ''

		# Calculate the time string based on the URI like before
		case uri
		when '', '/'
			timestring = time.to_s
		when '/epoch'
			timestring = time.to_i
		when '/rfc822', '/rfc2822'
			timestring = time.rfc2822
		when '/xmlschema'
			timestring = time.xmlschema
		else
			return
		end

		# Render the ERb template with a Binding of this scope
		response.body = template.result( binding() )

		response.headers[:content_type] = 'text/html'
		response.status = HTTP::OK
	end
end
