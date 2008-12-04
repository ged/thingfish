
### Random notes about converting the connection manager to an evented IO backend...

# States:
#   S : starting: 
#       => enable read event and move to [R0]
#   R0: reading, no active request
#       - read data into the read buffer
#       - if there's a blank line in the read buffer after a read:
#       => create a new request and move to [R1]
#   R1: reading with an active request
#       - read data into the read buffer
#       - if read buffer contains request's content-length bytes:
#       => if request isn't valid (method/body combo, etc?) move to [E]
#       => spool the body to disk, set it in the request, and move to [D]
#   D : dispatching request
#       - send the request to the daemon for dispatch, get a response back
#       => if there is an error condition move to [E]
#       - if the request is a HEAD, set the response body to the empty string
#       => write the response status and headers to write buffer, move to [W0]
#   E : error response
#       - Generate an error response, 
#       => write the response status and headers to write buffer, move to [W0]
#   W0: writing, write buffer full
#       - write to the socket and trim written bytes from the write buffer
#       - if buffer is now < bufsize, the body is an IO,
#         spool some to the write buffer
#       - else:
#       => disable write event and move to [N]
#   N : done with response, choosing whether or not to read the next request
#       - if current request and response both say connection: keep-alive and 
#         pipeline_max isn't exceeded: [R0]
#       - else: [C]
#   C : closing connection: [terminal]


stop writing when:
	write buffer is empty, and body is not an IO
	or write buffer is empty and body.io is at EOF

otherwise:
	if write_buffer length < bufsize
		if body is an IO
			enable :read for it in the reactor
		end
	end
	
	write stuff to the socket
end



BLANK_LINE = EOL + EOL

def initialize
	@read_buffer = ''
	@pending_request = nil
	@content_length = 0
	@continue = false
end

def on_read( socket )
	
	if offset = @read_buffer.index( BLANK_LINE )
		@pending_request = Request.parse( @read_buffer.slice!(0, offset) )
		@content_length = @pending_request.header[:content_length].to_i
	end
	
	if @pending_request && @read_buffer.length < @content_length
		@read_buffer.append( socket.sysread(@content_length - @read_buffer) )
	else
		@reactor.disable_events( @socket, :read )
		body = Tempfile.new( blah )
		body.write( @read_buffer.slice!(0, -1) )
		@pending_request.body = body
		
		response = self.call_the_daemon_callback( request )
		if @pending_request.keepalive? && response.keepalive?
			@continue = true
		end
		
		@write_buffer.append( response.to_s )
		@reactor.register( @socket, :write )
	else
		@read_buffer.append( socket.sysread(CHUNKSIZE) )
	end

end


def on_write( socket )
	if @write_buffer.empty?
		@reactor.disable_events( socket, :write )
		self.decide_whether_or_not_to_close_the_socket
	else
		bytes = socket.syswrite( @write_buffer, CHUNKSIZE )
		@write_buffer.slice!( 0, bytes )
	end
end



