#!/usr/bin/env ruby

require 'pp'
require 'strscan'
require 'tempfile'

EOL = /\r?\n/
BLANK_LINE = /#{EOL}#{EOL}/
BUFSIZE = 8192

def main( *args )
	files = {}
	metadata = {}

	content_type = 'multipart/form-data; boundary=0xKhTmLbOuNdArY'
	mimetype, boundary = content_type.
		scan( %r{(multipart/form-data).*boundary="?([^\";,]+)"?} ).first

	boundary_pat = Regexp.new( '--' + Regexp.escape( boundary ) )

	# boundary + double dashes 
	boundary_size = boundary.length + 2

	scanner = StringScanner.new('')
	io = File.open( ARGV[0] )

	until io.eof? && scanner.eos?
		puts "Bufferin'"
		io.read( BUFSIZE, scanner.string ) unless io.eof?

		if scanner.scan( boundary_pat )
			puts "Found one of them thar boundaries"
			if headerlines = scanner.scan_until( BLANK_LINE )
				puts "Found some header stuff: %p" % [headerlines]
				headers = headerlines.strip.split( EOL ).inject({}) {|hash, line|
					key,val = line.split( /:\s*/, 2 )
					hash[ key.downcase ] = val
					hash
				}

				# remove headers from parse buffer before writing file
				scanner.string.slice!( 0, scanner.pointer )
				scanner.reset

				# File data
				if headers['content-disposition'] =~ /filename="(?:.*\\)?(.+?)"/i
					filename = $1
					puts "Hey! It's a file chunker: %s" % filename
					tmpfile = Tempfile.open( 'filedata' )
					
					iobuf = ''
					until io.eof? && tmpfile.closed?
						puts "Chunkin' the file into a tempfile..."
						io.read( BUFSIZE, iobuf ) unless io.eof?
						scanner.string << iobuf

						if tmpfile.closed?
							puts "TEMPFILE IS CLOSED NOW: %s %s %d %d" % [ io.eof?, scanner.eos?, scanner.string.length, boundary_size ]
							next
						end

						# skip unless we have enough to read against
						next unless scanner.string.length >= boundary_size

						puts "scanner rest size: %d, boundary size + BUFSIZE: %d" % [
							scanner.rest_size, boundary_size + BUFSIZE
						]

						# look for end, store everything until boundary
						if scanner.check_until( boundary_pat )
							remnants = scanner.pre_match
							puts "Found the end: found %d bytes of data remaining" % [remnants.length]
							puts tmpfile.path
							tmpfile.write( remnants )
							tmpfile.close
							files[ tmpfile ] = { :title => filename, :format => headers['content-type'] }
							
							puts "advancing the scan pointer from %d to %d (out of %d)" % 
								[ scanner.pos, scanner.pos + remnants.length, scanner.string.length ]
							scanner.pos += remnants.length
							
						# not at the end yet, buffer this chunker to disk
						elsif scanner.rest_size >= boundary_size + BUFSIZE

							# make sure we're never writing a portion of the boundary
							# out while we're buffering
							buf = scanner.string.slice!( 0, scanner.rest_size - boundary_size )
							puts "okay, writing out %d bytes" % buf.size
							tmpfile.print( buf )
							
						end
					end

				# read metadata (name="thingfish-upload")
				elsif headers['content-disposition'] =~ /\bname="thingfish-metadata-(.*)"/i
					key = $1
					puts "Reading metadata"
					scanner.check_until( boundary_pat )
					value = scanner.pre_match

					# Handle multiple-value fields by converting to an array and 
					# appending
					#
					# TODO: re-visit when/if thingfish metastores support multi value
					# keys
					if metadata.key?( key )
						metadata[ key ] = [ metadata[key] ] unless 
							metadata[ key ].is_a?( Array )
						metadata[ key ] << value.chomp
					else
						metadata[ key ] = value.chomp
					end

					scanner.pos += value.length
				else
					# something we don't care about
					puts "Skipping extraneous form data"
					scanner.check_until( boundary_pat )
					scanner.pos += scanner.pre_match.length
				end
				
			# End of multipart
			elsif scanner.scan( /--/ )
				break
			end

		else
			raise "Boundary mismatch with presented form data"
		end

	end

	puts "Generic metadata: %p" % metadata

	i = 0
	files.each do |file, headers|
		puts '*' * 80
		puts "Specific metadata for this file: %p" % headers
		file.open
		new = File.new("/Users/mahlon/Desktop/#{i}.jpg", 'w')
		new.write( file.read )
		new.close
		i += 1
	end

end

main( ARGV ) if $0 == __FILE__

=begin
	forminfo = {}

	content_type = 'multipart/form-data; boundary=-----------------------------15462770211578279600427229456'
	mimetype, boundary = content_type.
		scan( %r{(multipart/form-data).*boundary="?([^\";,]+)"?} ).first

	tmp = File.open('/tmp/filedata', 'w+')

	# < 2 -- file data
	# 3   -- form data
	state   = nil
	metakey = nil
	buf     = ""

	io = File.open( ARGV[0] )
	io.each do |line|

		# reset
		state = nil if line.index( boundary )

		# looks like file data, buffer to spool file
		if ( state == 2 )
			if ( buf.size >= BUFSIZE )
				tmp.puts( buf )
				buf = ""
			end
			tmp.puts( buf ) if line.index( boundary )
			buf << line
		end

		# looks like form data
		if ( state == 3 and not metakey.nil? )
			next if line =~ /^\r?\n$/
			forminfo[ metakey.to_sym ] = line.chomp
		end

		# set state for file data
		if ( state.nil? and line =~ /filename="(?:.*\\)?(.*)"/i )
			state = 1
			forminfo[:title] = $1
		end
		if ( state == 1 )
			forminfo[:format] = $1 if line =~ /^Content-Type: (\S+)/i
			state = 2 if line =~ /^\r?\n$/
		end

		# set state for form data
		if ( state.nil? and line =~ / name="thingfish-metadata-(.*)"/i )
			state = 3
			metakey = $1
		end

	end

	pp forminfo

	tmp.rewind
	tmp.each do |l|
		puts l
	end
	tmp.close
end

main( ARGV ) if $0 == __FILE__
=end
