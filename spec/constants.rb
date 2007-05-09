
require 'thingfish'
require 'digest/md5'

module ThingFish::TestConstants

	TEST_CONTENT = <<EOF
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

end

