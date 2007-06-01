
require 'thingfish'
require 'digest/md5'
require 'net/http'
require 'net/protocol'

module ThingFish::TestConstants

	TEST_CONTENT = <<-'EOF'.gsub(/^\s*/, '')
	<html>
	<head>
		<title>Test Index</title>
	</head>
	<body>
		<h1>This is the test index content.</h1>
	</body>
	</html>
	EOF

	TEST_SERVER    		  = 'thingfish.laika.com'
	TEST_SERVER_URI		  = 'http://thingfish.laika.com:5000/'
	TEST_USERNAME		  = 'glimerrfeln'
	TEST_PASSWORD		  = 'holz$dg21b,'
	TEST_IP				  = '127.0.0.1'
	TEST_PORT			  = 3443
	TEST_RESOURCE_CONTENT = 'porn'
	TEST_UUID			  = '60acc01e-cd82-11db-84d1-7ff059e49450'
	TEST_UUID2			  = '06363890-c67f-11db-84a0-b7f0d178e52d'
	TEST_PROP			  = 'format'
	TEST_PROPVALUE		  = 'application/json'
	TEST_PROP2			  = 'turn_ons'
	TEST_PROPVALUE2		  = 'long walks on the beach'
	TEST_CHECKSUM		  = Digest::MD5.hexdigest( TEST_CONTENT )
	TEST_CONTENT_TYPE	  = 'text/html'
	HANDLER_TEST_UUID	  = UUID.parse( '1f770750-bb74-11db-afc1-97290f0c5beb' )

	# Fixtured HTTP responses
	TEST_OK_HTTP_RESPONSE = <<-'EOF'.gsub(/^\s*/, '')
	HTTP/1.0 200 OK
	Connection: close
	Expires: Tue, 13 May 2008 23:19:49 GMT
	Etag: "5f77bb4205ddd0482a834ab65a9cdbe4"
	Content-Type: image/jpeg
	Date: Mon, 14 May 2007 17:19:49 GMT
	Server: ThingFish/0.0.1 (Rev: 185 )
	Content-Length: 14620
	EOF

	### Return a Net::HTTPSuccess object with the contents set to the specified 
	### +data+.
	def with_fixtured_http_get_response( data='', code=HTTP::OK )
		data ||= ''
		raw_response = TEST_OK_HTTP_RESPONSE + "\n" + data
		io = Net::BufferedIO.new( StringIO.new(raw_response) )
		response = response_class_for_httpcode( code.to_s ).read_new( io )
		response['Content-Length'] = data.length
		response['Etag'] = %{"%s"} % Digest::MD5.hexdigest(data) if data

		response.reading_body( io, true ) do
			yield response if block_given?
		end
		return response
	end
	
	
	### Return the correct Net::HTTPResponse class for the given +code+ (because it's
	### private in Net::HTTPResponse itself)
	def response_class_for_httpcode( code )
		Net::HTTPResponse::CODE_TO_OBJ[code] or
		Net::HTTPResponse::CODE_CLASS_TO_OBJ[code[0,1]] or
		HTTPUnknownResponse
	end
	
	
	### Return a Net::HTTPSuccess object with empty contents, as if from a HEAD 
	### request.
	def with_fixtured_http_head_response
		raw_response = TEST_OK_HTTP_RESPONSE + "\n"
		io = Net::BufferedIO.new( StringIO.new(raw_response) )
		response = Net::HTTPResponse.read_new( io )

		response.reading_body( io, true ) do
			yield response if block_given?
		end
		return response
	end
	
end

