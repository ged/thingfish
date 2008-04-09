#!/usr/bin/ruby
# 
# Check the specified MAILDIR for new messages, delivering each to the given instance of ThingFish if any are found. 
# 
# == Synopsis
#
#   $ ml_archiver.rb OPTIONS MAILDIR [THINGFISH_HOST]
# 

BEGIN {
	require 'pathname'
	
	basedir = Pathname.new( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

begin
	require 'optparse'
	require 'ostruct'
	require 'tmail'
	require 'thingfish/client'
	require 'thingfish/resource'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


class MLArchiver


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
		# For each new mail
		maildir.each_new_port do |port|
			self.upload_port( port )
		end
	end


	### Look for any messages in the cur directory which have not been
	### marked as 'seen', and try to upload them.
	def retry_failed_messages( maildir )
		# For each new mail
		maildir.each_port do |port|
			next if port.seen?
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
		message( description )

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


	### Output a message to STDERR and flush it.
	def message( msg )
		$stderr.puts( msg.chomp )
		$stderr.flush
	end
		

	### Output +msg+ to STDERR and flush it if $VERBOSE is true.
	def verbose_msg( msg )
		message( msg ) if @options.verbose
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


if __FILE__ == $0
	options, maildir, host = MLArchiver.parse_options( ARGV )

	$stderr.puts "Got options: %p, maildir = %p, host = %p" % [ options, maildir, host ]

	archiver = MLArchiver.new( options, maildir, host )
	archiver.run
end

