#!/usr/bin/env ruby

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/handler/upload'


### A class for parsing multipart mime documents from a stream.
class ThingFish::MultipartMimeParser
	include ThingFish::Loggable

	# The buffer chunker size
	DEFAULT_BUFSIZE = 8192

	# The default location of upload temporary files
	DEFAULT_SPOOLDIR = '/tmp'
	
	# Parse patterns
	CRLF = /\r?\n/
	BLANK_LINE = /#{CRLF}#{CRLF}/
	
	# Parser state struct
	ParseState = Struct.new( "MPMParseState", :socket, :scanner, :boundary_pat,
		:boundary_size, :files, :metadata )
	

	### Create a new MultipartMimeParser that will parse uploads and metadata 
	### from the given +socket+ as a stream, and spool files to a temporary 
	### directory.
	def initialize( options={} )
		@bufsize  = options['bufsize']  || DEFAULT_BUFSIZE
		@spooldir = options['spooldir'] || DEFAULT_SPOOLDIR
	end


	######
	public
	######

	# The size of the buffer to use when spooling uploads, in bytes
	attr_accessor :bufsize
	
	# The directory to use for spooling uploads to temp files
	attr_accessor :spooldir


	### Examine multipart content, extract data and return hash
	### keyed on closed IO handles to filedata, values are metadata.
	def parse( socket, boundary )
		state = self.make_parse_state( socket, boundary )

		self.log.debug "Starting parse, boundary = %p" % [boundary]

		self.read_at_least( state.boundary_size, state.socket, state.scanner )
		state.scanner.skip( state.boundary_pat ) or
			raise ThingFish::RequestError, "No initial boundary"

		begin
			self.scan_part( state )
		end until state.scanner.scan( /--/ )

		self.log.debug "Finished parse. %d files, %d metadata pairs" %
			[ state.files.length, state.metadata.length ]
		return state.files, state.metadata
	end


	#########
	protected
	#########

	### Scan a part from the parse state.
	def scan_part( state )
		scanner = state.scanner
		
		scanner.skip( CRLF )
		scanner.string.slice!( 0, scanner.pos )
		scanner.reset
		self.log.debug "Scan pointer is at: %p" % [scanner.rest[0,100]]
		
		headers = self.scan_headers( state )

		# Figure out if it's a file
		if headers['content-disposition'] =~ /filename="(?:.*\\)?(.+?)"/i
			file = $1
			self.log.debug "Parsing an uploaded file (%p)" % [ file ]
			self.scan_file_body( file, headers['content-type'], state )
	
		# read metadata (name="thingfish-metadata-...")
		elsif headers['content-disposition'] =~ /\bname="thingfish-metadata-(\S+)"/i
			key = $1.gsub( /\W+/, '_' ).to_sym
			self.log.debug "Parsing a metadata parameter (%p)" % [key]
			self.scan_metadata_parameter( key, state )
	
		# form data that we don't care about
		else
			self.log.debug 'Skipping extraneous form data'
			until state.scanner.scan_until( state.boundary_pat )
				self.read_at_least( @bufsize, state.socket, state.scanner ) or
					raise ThingFish::RequestError, 
						"truncated mime document: EOF while scanning for next boundary"
			end
		end
	end
	
	
	### Scan the buffer for MIME headers and return them as a Hash.
	def scan_headers( state )
		scanner     = state.scanner
		headerlines = ''

		# Find the headers
		while headerlines.empty?
			if scanner.scan_until( BLANK_LINE )
				headerlines = scanner.pre_match
			else
				self.log.debug "Couldn't find a blank line in the first %d bytes (%p)" %
					[ scanner.restsize, scanner.rest[0..100]]
				self.read_at_least( @bufsize, state.socket, scanner ) or
					raise ThingFish::RequestError, "EOF while searching for headers"
			end
		end
		
		# put headers into a hash
		headers = headerlines.strip.split( CRLF ).inject({}) {|hash, line|
			key,val = line.split( /:\s*/, 2 )
			hash[ key.downcase ] = val
			hash
		}
		self.log.debug "Scanned headers: %p" % [headers]

		# remove headers from parse buffer
		scanner.string.slice!( 0, scanner.pointer )
		scanner.reset

		return headers
	end
	

	### Scan the value after the scan pointer for the specified metadata 
	### +parameter+.
	def scan_metadata_parameter( key, state )
		param = ''

		self.log.debug "Scanning metadata parameter: %p" % [key]
		while param.empty?
			if state.scanner.scan_until( state.boundary_pat )
				self.log.debug "Scanned for the end of the parameter. %p" %
					[state.scanner.pre_match]
				param = state.scanner.pre_match
			else
				self.read_some_more( state.socket, scanner ) or
					raise ThingFish::RequestError,
						"EOF while scanning for a metadata parameter"
			end
		end

		# Handle multiple-value fields by converting to an array and 
		# appending
		#
		# TODO: re-visit when/if thingfish metastores support multi value
		# keys
		if state.metadata.key?( key )
			state.metadata[ key ] = [ state.metadata[key] ] unless 
				state.metadata[ key ].is_a?( Array )
			state.metadata[ key ] << param.chomp
		else
			state.metadata[ key ] = param.chomp
		end
	
		self.log.debug "After the param, scan pointer is at: %p" % [state.scanner.rest[0,40]]
	end


	### Scan the body of the current document part, spooling the data to a tempfile
	### on disk and putting the resulting filehandle into the given +state+.
	def scan_file_body( filename, format, state )
		self.log.info "Parsing file '%s'" % [ filename ]
	
		tmpfile, size = self.spool_file_upload( state )
		self.log.debug "Scanned file to: %s (%d bytes)" % [tmpfile.path, size]
		state.files[ tmpfile ] = {
			:title  => filename,
			:format => format,
			:extent => size
		}
	end
	
	
	### Scan the file data and metadata in the given +scannner+, spooling the file 
	### data into a temporary file. Returns the tempfile object and a hash of 
	### metadata.
	def spool_file_upload( state )
		scanner = state.scanner
		io      = state.socket
		
		self.log.debug "Spooling file from upload"
		tmpfile = Tempfile.open( 'filedata', @spooldir )
		size = 0
	
		until tmpfile.closed?
			self.log.debug "buffering..."
	
			# look for end, store everything until boundary
			if scanner.scan_until( state.boundary_pat )
				self.log.debug "Found the end of the file"
				leavings = scanner.pre_match
				tmpfile.write( leavings )
				size += leavings.length
				tmpfile.close
	
			# not at the end yet, buffer this chunker to disk
			elsif scanner.rest_size >= state.boundary_size + @bufsize
				self.log.debug "splicing..."
	
				# make sure we're never writing a portion of the boundary
				# out while we're buffering
				buf = scanner.string.slice!( 0, 
					scanner.rest_size - state.boundary_size )
				tmpfile.print( buf )
				scanner.reset
				
				size += buf.length
			end

			# put some more data into the buffer
			unless tmpfile.closed?
				self.read_some_more( io, scanner ) or
					raise ThingFish::RequestError, "EOF while spooling file upload"
			end
		end
	
		return tmpfile, size
	end


	### Read at least +bytecount+ from the given +io+, appending the data onto the
	### specified +buffer+
	def read_at_least( bytecount, io, scanner )
		return false if io.eof?
		
		until scanner.restsize >= bytecount || io.eof?
			scanner << io.read( @bufsize )
			Thread.pass
		end
		
		return true
	end
	
	
	### Try to read another chunk of data into the buffer of the given +scanner+, 
	### returning true unless the +io+ is at eof.
	def read_some_more( io, scanner )
		return false if io.eof?
		startsize = scanner.restsize

		until scanner.restsize > startsize
			scanner << io.read( @bufsize )
			Thread.pass
		end
			
		return true
	end
	
	
	### Create a new ParseState struct for an upcoming parse, using the specified
	### +boundary+ string for the boundary pattern.
	def make_parse_state( socket, boundary )

		# boundary + double dash prefix (rfc 1341)
		boundary_pat  = Regexp.new( Regexp.escape('--' + boundary) )
		boundary_size = boundary.length * 1.5
		scanner  = StringScanner.new( '' )

		return ParseState.new( socket, scanner, boundary_pat, boundary_size, {}, {} )
	end
	
	
end # class ThingFish::UploadHandler::MultipartMimeParser

