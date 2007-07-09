#!/usr/bin/env ruby
# 
# thingfish - a command-line interface to ThingFish servers
# 
# == Synopsis
# 
#   $ thingfish upload FILE
# 
# == Version
#
#  $Id$
# 
# 

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = basedir + 'lib'
	
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	require basedir + 'utils.rb'
	include UtilityFunctions
}


require 'thingfish'
require 'net/http'
require 'uri'



class ThingFish::CommandLineClient
	
	### Create a new ThingFish::CommandLineClient
	def initialize
		@mime_analyzer = nil
	end
	
	
	######
	public
	######

	### Main logic
	def main( uri, verb, *args )
		uri = URI.parse( uri ) or raise "invalid uri '%s'" % [uri]
	
		until args.empty?
			case verb
			when /^(upload|post)$/i
				file = args.shift
				do_upload( uri, file )
		
			when /^(update|put)$/i
				uuid = args.shift or raise "no UUID specified for update"
				file = args.shift
				do_update( uri, uuid, file )
		
			when /^(download|get|fetch)$/
				uuid = args.shift or raise "no UUID specified for fetch"
				file = args.shift
				do_download( uri, uuid, file )
		
			when /^(check|head|info)$/
				uuid = args.shift or raise "no UUID specified for check"
				do_check( uri, uuid )
		
			else
				raise "Don't know how to '#{verb}' yet."
			end
		end
	end


	#########
	protected
	#########


	### Upload the contents of the specified +file+ to the ThingFish at the given +uri+. 
	### If +file+ is nil, the content will be read from STDIN instead.
	def do_upload( uri, file=nil )
		fh = get_reader_io( file )
		mimetype = get_mimetype( fh )

		req = Net::HTTP::Post.new( uri.path )
		req.body_stream = fh
		req['Content-Type'] = mimetype
		req['Content-Length'] = fh.stat.size

		response = send_request( uri, req )
		location = response['location']
	
		$stderr.puts "Uploaded to: #{location}"
	end


	### Update the resource at the specified +uuid+ on the ThingFish at the given +uri+
	### with the content from the specified +file+. If +file+ is nil, the content will
	### be read from STDIN instead.
	def do_update( uri, uuid, file=nil )
		fh = get_reader_io( file )
		mimetype = get_mimetype( fh )

		uri.path += uuid
	
		req = Net::HTTP::Put.new( uri.path )
		req.body_stream = fh
		req['Content-Type'] = mimetype
		req['Content-Length'] = fh.stat.size

		response = send_request( uri, req )
		$stderr.puts "Updated #{uuid}"
	end


	### Fetch the resource at the specified +uuid+ on the ThingFish at the given +uri+
	### and write it to the specified +file+. If +file+ is nil, the content will be
	### written to STDOUT instead.
	def do_download( uri, uuid, file )
		uri.path += uuid
	
		req = Net::HTTP::Get.new( uri.path )
		req['Accept'] = '*/*'

		# Send the request and read the body of the response into the filehandle
		send_request( uri, req ) do |response|
			bytes = 0
			fh = get_writer_io( file )

			response.read_body do |chunk|
				bytes += chunk.size
				fh.print( chunk )
			end

			fh.close
			$stderr.puts "Wrote %d bytes from %s." % [ bytes, uuid ]
		end
	end


	### Fetch the headers for the specified +uuid+ on the ThingFish at the given +uri+
	### and output them to stdout.
	def do_check( uri, uuid )
		uri.path += uuid
	
		req = Net::HTTP::Head.new( uri.path )
		req['Accept'] = '*/*'

		# Send the request and read the body of the response into the filehandle
		send_request( uri, req ) do |response|
			bytes = 0
			$stdout.puts( response.inspect )
		end
	end


	### Get an IO object for reading from the specified +filename+. If +filename+ is 
	### +nil+, returns the IO for STDIN instead.
	def get_reader_io( filename=nil )
		return $defin unless filename
		return File.open( filename, File::RDONLY )
	end


	### Get an IO object for writing to the specified +filename+. If +filename+ is 
	### +nil+, returns the IO for STDOUT instead.
	def get_writer_io( filename=nil )
		return $stdout unless filename
		return File.open( filename, File::WRONLY|File::CREAT|File::TRUNC )
	end


	### Send the given HTTP::Request to the host and port specified by +uri+ (a URI 
	### object). The +limit+ specifies how many redirects will be followed before giving 
	### up.
	def send_request( uri, req, limit=10, &block )
		req['User-Agent'] = 'ThingFish Test Client/$Rev$'
		$stderr.puts "Request: ", dump_request_object( req )
		response = nil
		
		if ENV['http_proxy']
			$stderr.puts "Using proxy #{ENV['http_proxy']}..."
			proxyuri = URI.parse( ENV['http_proxy'] )
			proxy = Net::HTTP::Proxy( proxyuri.host, proxyuri.port )
			response = proxy.start( uri.host, uri.port ) do |conn|
				conn.read_timeout = 600
				conn.request( req, &block )
			end
		else
			response = Net::HTTP.start( uri.host, uri.port ) do |conn|
				conn.request( req, &block )
			end
		end
	
		$stderr.puts "Response:", dump_response_object( response )

		case response
	
		# 2xx -> Success
		when Net::HTTPSuccess
			return response
		
		# 3xx -> Redirect (:TODO: what about 304 NOT MODIFIED?)
		when Net::HTTPRedirection
			uri = URI.parse( response['location'] )
			return send_request( response['location'], req, limit - 1 )

		# 401 -> Ask for authentication
		when Net::HTTPUnauthorized
			limit = 3 if limit > 3 # Only try 3 times instead of the default
			response.error! if limit.zero?
			add_authentication( response, req )
			return send_request( uri, req, limit - 1 )
		
		else
			# Raise an appropriate exception
			response.error!
		end

	end


	### Return the request object as a string suitable for debugging
	def dump_request_object( request )
		buf = "#{request.method} #{request.path} HTTP/#{Net::HTTP::HTTPVersion}\r\n"
		request.each_capitalized do |k,v|
			buf << "#{k}: #{v}\r\n"
		end
		buf << "\r\n"

		return buf
	end


	### Return the response object as a string suitable for debugging
	def dump_response_object( response )
		buf = "#{response.code} #{response.message}\r\n"
		response.each_capitalized do |k,v|
			buf << "#{k}: #{v}\r\n"
		end
		buf << "\r\n"
		
		return buf
	end
	

	### Add the authentication of the type specified by the given +response+ to the
	### given request.
	def add_authentication( response, request )
		authtype = response['WWW-Authenticate'] or response.error!

		case authtype
		when /basic/i
			username, password = prompt_for_authentication( response )
			req.basic_auth( username, password )
		
		else
			code = response.code
			msg = response.message.dump + 
				" and requested authtype (#{authtype}) not supported"
	      	raise response.error_type.new( code + ' ' + msg, response )
		end
	end


	### Prompt the user for authentication to the realm specified in the given +response+.
	def prompt_for_authentication( response )
		require 'password'
		require 'etc'

		curuser = Etc.getpwuid( Process.euid ).name

		username = prompt_with_default( "Username", curuser ) {|name| name =~ /^\w+$/}
		password = Password.get( "Password" )
	
		return username, password
	end


	# Create an object to deduce mimetypes.
	def get_mime_analyzer
		unless @mime_analyzer
			begin
				require 'mahoro'
				$stderr.puts "Using Mahoro for MIME analysis"
				flags = Mahoro::SYMLINK|Mahoro::MIME
				@mime_analyzer = Mahoro.new( flags )
			rescue LoadError
			end
	
			unless @mime_analyzer
				begin
					require 'filemagic'
					$stderr.puts "Using Filemagic for MIME analysis"
					flags = FileMagic::MAGIC_SYMLINK|FileMagic::MAGIC_MIME
					@mime_analyzer = FileMagic.new( flags )
				rescue LoadError
				end
			end
	
			unless @mime_analyzer
				@mime_analyzer = Class.new do
					def file( ignored )
						return 'application/octet-stream'
					end
					def buffer( ignored )
						return 'application/octet-stream'
					end
				end.new
			end

		end
		
		return @mime_analyzer
	end


	### Try to deduce a mimetype from the first 2k of data read from the given +io+ and 
	### return it. The IO object will be rewound before returning.
	def get_mimetype( io )
		data = io.read( 2048 )
		io.rewind

		analyzer = get_mime_analyzer or
			raise "Ack. None of the strategies for deriving mimetype worked."

		return analyzer.buffer( data )
	end
end


if __FILE__ == $0
	$DEBUG = true
	progname = Pathname.new( $0 ).basename
	
	begin
		raise "Usage: #{progname} THINGFISH_URL ACTION" unless ARGV.length >= 2
		client = ThingFish::CommandLineClient.new

		client.main( *ARGV )
	rescue => err
		$stderr.puts "ERROR: #{err.message}"
		$stderr.puts "  " + err.backtrace.join( "\n  " ) if $DEBUG
	end
end

# vim: set nosta noet ts=4 sw=4:
