#!/usr/bin/env ruby

require 'fileutils'

### Open a file and filter each of its lines through the given block a
### <tt>line</tt> at a time. The return value of the block is used as the
### new line, or omitted if the block returns <tt>nil</tt> or
### <tt>false</tt>.
def edit_in_place( file, testMode=false ) # :yields: line
	raise "No block specified for editing operation" unless block_given?

	tempName = "#{file}.#{$$}"
	File.open( tempName, File::RDWR|File::CREAT, 0600 ) do |tempfile|
		File.open( file, File::RDONLY ) do |fh|
			fh.each do |line|
				newline = yield( line ) or next
				tempfile.print( newline )
				$stderr.puts "%p -> %p" % [ line, newline ] if
					line != newline
			end
		end
	end

	if testMode
		File.unlink( tempName )
	else
		File.rename( tempName, file )
	end
end


ARGV.each do |file|
	edit_in_place( file, true ) do |line|
		line.
			gsub(/should_/, 'should ').
			gsub(/should not_/, 'should_not ').
			gsub(/should receive/, 'should_receive').
			gsub(/should raise/, 'should raise_error').
			gsub(/should_not raise/, 'should_not raise_error')
	end
end


