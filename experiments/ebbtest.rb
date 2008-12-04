#!/usr/bin/env ruby

require 'rubygems'
require 'ebb'
require 'pp'

module Ebb::Server
	InnerClass = (class << Ebb::FFI; self; end)
	
	%w{
		server_process_connections
		server_listen_on_fd
		server_listen_on_port
		server_listen_on_unix_socket
		server_unlisten
		server_open?
		server_waiting_clients
	}.each do |meth|
		# $stderr.puts "Re-delegating #{meth} into the mixin module"
		unbound_method = InnerClass.instance_method( meth )
		bound_method = unbound_method.bind( Ebb::FFI )
		define_method( meth, &bound_method )
	end
end


class MyServer
	include Ebb::Server
	
	def initialize
		@running = false
		@request_num = 0
	end
	
	
	def start
		self.server_listen_on_port( 3474 )
		@running = true
		haltblock = self.method( :stop_server )
		Signal.trap( 'INT', &haltblock )
		Signal.trap( 'TERM', &haltblock )
	
		while @running
			self.server_process_connections
			
			while client = self.server_waiting_clients.shift
				$stderr.puts "New connection"
				Thread.new( client ) {|c| self.process( c ) }
			end
		end

		$stderr.puts "Default thread group contains:\n"
		ThreadGroup::Default.list.each do |thr|
			p thr
		end
		
		$stderr.puts "Telling server backend to unlisten"
		self.server_unlisten
	end


	def stop_server( *args )
		$stderr.puts "Stopping server"
		@running = false
	end
	
	def process( client )
		@request_num += 1
		$stderr.puts "processing client request %d" % [ @request_num ]
		content = ''
		PP.pp( client.env, content )
		
		$stderr.puts "Sleeping a bit"
		sleep 5
		$stderr.puts "Okay, waking up and writing to the client"
		
		client.write_status( 200 )
		client.write_header( 'Content-type', 'text/plain' )
		client.write_header( 'Content-length', content.length.to_s )
		client.write_header( 'Connection', 'close' )
		
		client.write_body( content )
		client.write_body( "more stuff" )
	rescue => err
		$stderr.puts "Error: #{err.message}"
		$stderr.puts "  " + err.backtrace.join( "\n  " )
	ensure
		client.release
	end	
	
end


if $0 == __FILE__
	s = MyServer.new
	s.start
end


