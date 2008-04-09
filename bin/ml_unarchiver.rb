#!/usr/bin/ruby
# 
# Copy the email out of the given
# 
# == Synopsis
#
#   $ ml_unarchiver.rb maildir [message_files]
# 

require 'rubygems'
require 'tmail'
require 'pathname'

maildir_path = ARGV.shift or
	raise "first argument must be a Maildir"

maildir = TMail::Maildir.new( maildir_path )


ARGV.collect {|fn| Pathname.new(fn) }.each do |file|
	$stderr.puts "Copying %s" % [ file ]
	maildir.new_port do |fh|
		fh.write( file.read )
	end
end

	
