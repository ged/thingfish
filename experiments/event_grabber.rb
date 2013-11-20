#!/usr/bin/env ruby
#

require 'zmq'

ctx = ZMQ::Context.new
sock = ctx.socket( ZMQ::SUB )
sock.setsockopt( ZMQ::SUBSCRIBE, 'create' )
sock.connect( 'tcp://127.0.0.1:3475' )

while msg = sock.recv
	puts msg
end

