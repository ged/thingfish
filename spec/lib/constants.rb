
require 'thingfish'
require 'digest/md5'
require 'net/http'
require 'net/protocol'

module ThingFish::TestConstants

	unless defined?( TEST_CONTENT )
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
		TEST_UUID3			  = '26A4EBA6-1264-4269-AC0A-82A80C0FDB4D'
		TEST_PROP			  = 'format'
		TEST_PROPVALUE		  = 'application/json'
		TEST_PROP2			  = 'turn_ons'
		TEST_PROPVALUE2		  = 'long walks on the beach'
		TEST_CHECKSUM		  = Digest::MD5.hexdigest( TEST_CONTENT )
		TEST_CONTENT_TYPE	  = 'text/html'
		TEST_UUID_OBJ	      = UUID.parse( '60acc01e-cd82-11db-84d1-7ff059e49450' )
		TEST_ACCEPT_HEADER    = 'application/x-yaml, application/json; q=0.2, text/xml; q=0.75'
		TEST_RUBY_OBJECT	  = { 'pine cone' => 'sandwiches', 'olive oil' => 'pudding' }
		TEST_TITLE            = 'Muffin the Panda Goes To School'
		TEST_PROPSET 		  = {
			TEST_PROP  => TEST_PROPVALUE,
			TEST_PROP2 => TEST_PROPVALUE2,
			'extent'   => "213404",
			'checksum' => '231c9a4500f2448e3bdec11c8baedc53',
		}
		

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
	end
end

# vim: set nosta noet ts=4 sw=4:
