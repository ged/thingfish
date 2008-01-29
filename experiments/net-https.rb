#!/usr/bin/ruby

require 'net/https'


uri = URI.parse( 'https://laikapedia.laika.com/auth/login.html' )

http = Net::HTTP.new( uri.host, uri.port.to_i )
http.use_ssl = true

header = {
	'User-Agent' => 'Net::HTTP',
	'Connection' => 'close',
	'Accept' => 'text/html',
}
req = Net::HTTP::Get.new( uri.path )
res = http.start do |conn|
	conn.request( req )
end

p res

