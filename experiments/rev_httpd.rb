#!/usr/bin/env ruby

require 'rubygems'
require 'rev'
require 'http11'
require 'pp'

HOST = '0.0.0.0'
PORT = 4321


class HttpSession < Rev::TCPSocket
	
	RESPONSE_TEMPLATE = %{
		Content-Type: text/plain\r
		Content-Length: %d\r
		Connection: close\r
		\r
		%s\r
	}.gsub( /^\t\t/m, '' )
	
	def initialize( socket )
		@socket = socket
		@headers = {}
		@handled = false
		@request_parser = Mongrel::HttpParser.new
		
		super
	end
	
	
	def on_connect
		puts "#{remote_addr}:#{remote_port} connected"
	end

	def on_close
		puts "#{remote_addr}:#{remote_port} disconnected"
	end

	def on_read( data )
		puts "#{remote_addr}:#{remote_port} is now readable"
		puts "Parsing:", data
		@request_parser.execute( @headers, data, 0 )
		hdrstring = ''
		PP.pp( @headers, hdrstring )
		puts "Headers are: ", hdrstring

		body = "Hi! I'm in thread %p!" % [ Thread.current ]
		response = RESPONSE_TEMPLATE % [ body.length, body ]
		@handled = true

		self.write( body )
	end
	
	def on_write_complete
		puts "Write complete for #{remote_addr}:#{remote_port}"
		if @handled
			puts "  request is handled: disconnecting"
			self.detach
			@socket.close
		end
	end
end

server = Rev::TCPServer.new( HOST, PORT, HttpSession )
server.attach( Rev::Loop.default )

puts "Rev mini-webserver listening on #{HOST}:#{PORT}"
Rev::Loop.default.run
puts "Default loop done."

