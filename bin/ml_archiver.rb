#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'tmail'
require 'thingfish/client'
require 'thingfish/resource'

# 
# Check the specified MAILDIR for new messages, delivering each to the 
# given instance of ThingFish if any are found.
# 
# == Synopsis
#
#   $ ml_archiver.rb OPTIONS MAILDIR [THINGFISH_HOST]
# 
class DefaultArchiver

	@available_archivers = [ self ]
	class << self
		attr_reader :available_archivers
	end


	### When inherited, register the new subclass as an available archiver.
	def self::inherited( klass )
		@available_archivers << klass
		super
	end


	### Return a list of human-friendly archiver names with the word "archiver"
	### stripped off and the remainder downcased.
	def self::archiver_names
		available_archivers.map {|klass| klass.name.sub( /Archiver$/, '' ).downcase }
	end


	### Given a human-friendly archiver name, return the corresponding class
	### object
	def self::get_archiver( name )
		archiver = available_archivers.select {|klass| klass.name.downcase =~ /#{name}/}

		raise "Ambiguous archiver name '#{name}'; found: #{archiver.inspect}" if
			archiver.size > 1

		raise "No archiver found to match '#{name}'" if archiver.empty?

		return archiver.first
	end


	DEFAULT_HOST = 'localhost'
	DEFAULT_PORT = ThingFish::Constants::DEFAULT_PORT


	### Parse the given command-line +arguments+ and return an
	### OpenStruct with options, the target maildir, and the thingfish
	### host to upload to.
	def self::parse_options( argv )
		program = Pathname.new( $0 ).basename

		options = self.default_config

		oparser = OptionParser.new do |oparser|
			oparser.banner = "Usage: %s [options] ./Maildir [thingfish-host]" % [ program ]

			oparser.separator ''
			oparser.separator "Runtime options"

			oparser.on( '-v', '--verbose', FalseClass, "Turn verbose output on" ) do
				options.verbose = true
			end

			oparser.on( '-d', '--debug', FalseClass, "Turn debugging output on" ) do
				options.debugging = true
			end

			oparser.on( '-n', '--dry-run', FalseClass, "Don't actually upload anything, ",
				"just show what would be done." ) do
				options.dryrun = true
			end

			oparser.on( '-k', '--keep-going', FalseClass, "Keep going after an upload error." ) do
				options.keepgoing = true
			end

			oparser.on( '-a', '--archiver=STRING', String,
				"Select which archiver to use.",
				"Available archivers: ",
				"\t" + archiver_names.join( ", " )
			) do |argval|
				options.archiver = argval
			end

			oparser.separator ''
			oparser.separator "ThingFish options"

			oparser.on( '-p', '--port=PORT', Integer, "Port ThingFish server is listening on" ) do |port|
				options.port = port
			end

			oparser.separator ''
			oparser.separator "Informational options"

			oparser.on( '-h', '--help', FalseClass, "Output this help and quit." ) do
				$stderr.puts( oparser )
				exit!( 0 )
			end

		end

		maildir, host = oparser.parse!( argv )

		if maildir.nil?
			$stderr.puts( oparser )
			exit!( 64 )
		end

		return options, maildir, host || DEFAULT_HOST
	end


	### Return a struct which contains the default config values, appropriate
	### for passing as the first argument to #main
	def self::default_config
		options = OpenStruct.new

		options.port		= DEFAULT_PORT
		options.debugging	= false
		options.dryrun		= false
		options.keepgoing	= false
		options.archiver    = 'default'

		return options
	end


	### Create a new archiver object
	def initialize( options, maildir, host )
		@options = options
		@maildir = Pathname.new( maildir )
		@host = host

		tf_uri = "http://#{@host}:#{@options.port}/"
		@client = ThingFish::Client.new( tf_uri )
	end


	### Run the archiver.
	def run
		raise "#{@maildir}: Not a directory" unless @maildir.directory?

		debug_msg "Uploading to the ThingFish server at #{@client.uri}"

		# Open the maildir
		maildir = TMail::Maildir.new( @maildir )

		self.retry_failed_messages( maildir )
		self.upload_new_messages( maildir )
		self.cleanup( maildir )

	rescue => err
		error_msg err.message
		debug_msg "  " + err.backtrace.join( "\n  " )
	end


	### Look in the maildir for any new messages and attempt to upload
	### them. Any messages seen will be moved to the 'cur' directory,
	### and then tagged with the 'seen' flag if they were successfully
	### uploaded.
	def upload_new_messages( maildir )
		message "Uploading new messages"

		message_count = Dir.glob( maildir.directory + 'new/*' ).size
		count = 0

		# For each new mail
		maildir.each_new_port do |port|
			debug_msg "processing port in file #{port.filename}"

			count += 1
			progress_msg "#{count}/#{message_count}"

			self.upload_port( port )
		end
	end


	### Look for any messages in the cur directory which have not been
	### marked as 'seen', and try to upload them.
	def retry_failed_messages( maildir )
		message "Retrying failed messages"

		message_count = Pathname.glob( maildir.directory + 'cur/*' ).reject {|pn| pn.to_s =~ /,S$/ }.size
		count = 0

		# For each new mail
		maildir.each_port do |port|
			debug_msg "processing port in file #{port.filename}"

			if port.seen?
				verbose_msg "skipping seen port"
				next
			end

			count += 1
			progress_msg "#{count}/#{message_count}"
			debug_msg "  retrying upload of port #{port} from 'cur'"

			self.upload_port(port)
		end
	end


	### Clean up any messages in the 'cur' directory of the +maildir+
	### if it's been marked as 'seen'.
	def cleanup( maildir )
		maildir.each_port do |port|
			next unless port.seen?

			wet_action("cleaning up old message #{port}") do
				port.remove
			end
		end
	end



	#########
	protected
	#########

	### (An action to take in 'wet' mode) The block will be called if
	### the program isn't run in 'dry mode'.
	def wet_action( description )
		verbose_msg( description )

		yield unless @options.dryrun
	end


	### Send the specified TMail::MaildirPort to the configured ThingFish server.
	def upload_port( port )
		message = TMail::Mail.new( port )
		debug_msg "Uploading %p to %s" % [ port, @client.uri ]

		# send it to the server
		begin
			resource = ThingFish::Resource.from_file( port.filename, :archiver => $0, :archive_time => Time.now.to_s )
			resource.extent = port.size
			resource.format = 'message/rfc822'
			resource.title = message.message_id
			resource.list_name = parse_list_name( message )
			wet_action("Storing message in ThingFish") do
				@client.store( resource )
			end
		rescue => err
			if @options.keepgoing
				error_msg "Problem uploading %s: %s" % [ port, err.message ]
				debug_msg "  " + err.backtrace.join( "\n  " )
			else
				raise err.exception( "Problem while uploading: #{err.message}" )
			end
		else
			# mark it as being read
			debug_msg "  great success! Marking it as uploaded!"
			wet_action("Marking port as 'seen'") do
				port.seen = true
			end
		end

		debug_msg "Uploaded as %s" % [ resource.uuid ]
	end


	### Given a mailing list message, parse out the name of the mailing list
	### that it was sent to
	def parse_list_name( message )
		message[ 'delivered-to' ]
	end


	### Output a message to STDERR and flush it.
	def message( msg )
		$stderr.puts( msg.chomp )
		$stderr.flush
	end


	### Output +msg+ to STDERR and flush it if $VERBOSE is true.
	def verbose_msg( msg )
		message( msg ) if @options.verbose
	end


	### Output a progress message to stderr if debugging is off, resetting the
	### line before printing.
	def progress_msg( msg )
		$stderr.print "\rProgress: #{msg}" unless @options.debugging || @options.verbose
	end


	### Output a message 
	def debug_msg( msg )
		message( "DEBUG>> #{msg}" ) if @options.debugging
	end


	### Output an error message
	def error_msg( msg )
		message( "ERROR: #{msg}" )
	end
end


class EZMLMArchiver < DefaultArchiver
	def parse_list_name( message )
		delivered_to = message[ 'delivered-to' ].body

		list_name = delivered_to[ /(\S+)$/, 1 ] or raise
			"Could not parse listname from #{delivered_to.inspect}"

		return list_name
	end
end


if __FILE__ == $0
	options, maildir, host = DefaultArchiver.parse_options( ARGV )
	archiver_class = DefaultArchiver.get_archiver( options.archiver )

	$stderr.puts "Got options: %p, archiver: %p, maildir = %p, host = %p" %
		[ options, archiver_class, maildir, host ]

	archiver = archiver_class.new( options, maildir, host )
	archiver.run
end

