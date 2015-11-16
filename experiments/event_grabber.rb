#!/usr/bin/env ruby
#

require 'zmq'

ctx = ZMQ::Context.new
sock = ctx.socket( ZMQ::SUB )
sock.subscribe( '' )
sock.connect( 'tcp://127.0.0.1:3475' )
#sock.connect( 'epgm://eth0:226.1.1.1:3475' )

while msg = sock.recv
	puts msg
end

