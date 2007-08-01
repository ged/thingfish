#!/usr/bin/ruby
#
# A disk filesystem-based ThingFish FileStore plugin.
# 
# This FileStore stores resources on disk in a hierarchy of hashed directories. It uses
# NFS-safe locking for writes, and should be threadsafe.
# 
# == Configuration
# 
# To run this handler in your ThingFish, set the 'name' value in your
# config file's 'filestore' section to 'filesystem'.
# 
#   filestore:
#     name: filesystem
#     root: /tmp/thingstore
# 
# === Config Keys
# 
# [+root+]
#   The directory in which to create the hashed directory structure and store uploaded
#   resources. Defaults to ThingFish::FilesystemFileStore::DEFAULT_ROOT.
# [+hashdepth+]
#   The number of subdirectories to use. Can be set to 1, 2, 4, or 8. Defaults to 
#   ThingFish::FilesystemFileStore::DEFAULT_HASHDEPTH.
# [+bufsize+]
#   The size of the buffer to use when reading incoming data (in bytes). Defaults to
#   ThingFish::FilesystemFileStore::DEFAULT_BUFSIZE.
# [+spooldir+]
#   The directory to use when spooling uploaded files (relative to the +root+). 
#   Defaults to ThingFish::FilesystemFileStore::DEFAULT_SPOOLDIR.
# [+locking+]
#   The configuration for the locking system. Defaults are in 
#   ThingFish::FilesystemFileStore::DEFAULT_LOCKING_OPTIONS.
#   [+retries+]
#     How many times to retry the lock if it can't be acquired.
#   [+sleep_inc+]
#     The number of seconds to increment each sleep cycle from min_sleep to max_sleep.
#   [+min_sleep+]
#     The shortest amount of time to sleep when waiting for a lock.
#   [+max_sleep+]
#     The longest amount of time to sleep when waiting for a lock.
#   [+max_age+]
#     Locks older than +max_age+ will be deleted (stolen).
#   [+suspend+]
#     If a lock is stolen from someone else, wait +suspend+ seconds to give them a 
#     chance to realize it.
#   [+refresh+]
#     Number of seconds between updates to the lockfile by the background thread.
#   [+timeout+]
#     Maximum number of seconds to wait for the lock.
#   [+poll_retries+]
#     Number of times to poll for the lock on each retry.
#   [+poll_max_sleep+]
#     The maximum amount of time to wait between each poll for the lock, in seconds.
#   [+dont_clean+]
#     If this is set to +true+, don't clean up after lockfiles at exit.
#   [+dont_sweep+]
#     If set to +true+, don't attempt to find and remove any old temp files created
#     by processes of this host which are no longer alive.
#   [+debug+]
#     If set to +true+, print trace execution progress on stdout.
#     
#     
# == License
# 
# Copyright (c) 2007 LAIKA, Inc. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution-ShareAlike
# License. To view a copy of this license, visit
# http://creativecommons.org/licenses/by-sa/1.0/ or send a letter to Creative
# Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
# 
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#

require 'tmpdir'
require 'pathname'
require 'lockfile'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/filestore'


### A filesystem based filestore plugin for ThingFish
class ThingFish::FilesystemFileStore < ThingFish::FileStore
	include ThingFish::Constants::Patterns

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# Number of bytes in one megabyte
	ONE_MEGABYTE = 1024**2

	# The default filesystem root to store stuff in
	DEFAULT_ROOT = File.join( Dir.tmpdir, 'thingstore' )

	# The default number of hashed directories
	DEFAULT_HASHDEPTH = 4

	# The buffer chunker size
	DEFAULT_BUFSIZE = 8192

	# The default location of upload temporary files
	# (relative to DEFAULT_ROOT)
	DEFAULT_SPOOLDIR = 'spool'

	# The default options to use when creating locks. See the docs for Lockfile for
	# more info on what these values mean
	DEFAULT_LOCKING_OPTIONS = {
		:retries        => nil,		# retry forever
		:sleep_inc      => 2,
		:min_sleep      => 2,
		:max_sleep      => 32,
		:max_age        => 1024,
		:suspend        => 64,
		:refresh        => 8,
		:timeout        => nil,		# Wait for a lock forever
		:poll_retries   => 16,
		:poll_max_sleep => 0.08,
		:dont_clean     => false,
		:dont_sweep     => false,
		:debug			=> false,
	  }
	

	
	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new FilesystemFileStore
	def initialize( options={} )
		super
		@root      = Pathname.new( options[:root] || DEFAULT_ROOT )
		@hashdepth = @options[:hashdepth] || DEFAULT_HASHDEPTH
		@bufsize   = @options[:bufsize]   || DEFAULT_BUFSIZE
		@lock_opts = @options[:locking]   || DEFAULT_LOCKING_OPTIONS
		@spooldir  = @options[:spooldir]  || DEFAULT_SPOOLDIR
		
		raise ThingFish::ConfigError, "Max hash depth (8) exceeded" if @hashdepth > 8
		raise ThingFish::ConfigError, "Hash depth must be 1, 2, 4, or 8." \
		 	unless [ 1, 2, 4, 8 ].include?( @hashdepth )
		
		# Create the root if it doesn't already exist
		@root.mkpath unless @root.exist?
		@total_size = find_filestore_size()
	end



	######
	public
	######

	# The number of hashed subdirectories to use
	attr_reader :hashdepth
	
	# The filesystem root (as a Pathname object)
	attr_reader :root
	

	### Mandatory FileStore interface

	### FileStore API: write the specified +data+ to the store at the given +uuid+.
	def store( uuid, data )
		raise ThingFish::FileStoreQuotaError, "FileStore quota limit exceeded" if
			@options[:maxsize] && @total_size + data.length > @options[:maxsize]

		self.open_writer( uuid ) do |fh|
			fh.write( data )
		end
		
		@total_size += data.length
		return Digest::MD5.hexdigest( data )
	end


	### FileStore API: Store the data read from the given +io+ in the store at the given +uuid+.
	def store_io( uuid, io )
		maxsize = @options[:maxsize]
		uploadsize = 0

		digest = Digest::MD5.new
		self.open_writer( uuid ) do |fh|
	
			# Buffered read
			buf = ''
			while io.read( @bufsize, buf )
				uploadsize += buf.length
				raise ThingFish::FileStoreQuotaError, "FileStore quota limit exceeded" if
					maxsize && @total_size + uploadsize > maxsize

				digest << buf
				until buf.empty?
					bytes = fh.write( buf )
					buf.slice!( 0, bytes )
				end
			end
		end

		@total_size += uploadsize
		return digest.hexdigest
	end
	

	### FileStore API: read the data in the store at the given +uuid+.
	def fetch( uuid )
		io = self.open_reader( uuid ) or return nil
		return io.read
	end
	
	
	### FileStore API: Retrieve an IO for the data corresponding to the given +uuid+.
	### If a block is given, 
	def fetch_io( uuid )
		io = self.open_reader( uuid )
		
		if block_given?
			begin
				yield( io )
			ensure
				io.close if io && !io.closed?
			end
		else
			return io
		end
	end
	

	### FileStore API: delete the data in the store at the given +uuid+ and return its
	### data (if it existed).
	def delete( uuid )
		path = self.hashed_path( uuid )
		bytes = path.size
		if path.unlink
			@total_size -= bytes
			return true
		else
			return false
		end
	rescue Errno::ENOENT
		return false
	end


	### Return +true+ if the store has a file corresponding to the specified +uuid+.
	def has_file?( uuid )
		return self.hashed_path( uuid ).exist?
	end


	### Return the size of the resource corresponding to the given +uuid+ in bytes. 
	### Returns +nil+ if the given +uuid+ is not in the store.
	def size( uuid )
		path = self.hashed_path( uuid )
		return path.exist? ? path.size : nil
	end
	
	
	### Mandatory Admin interface

	# The number of bytes currently in the filestore
	attr_reader :total_size



	#########
	protected
	#########

	### Return the full path on disk for a given uuid
	def hashed_path( uuid )
		uuid = uuid.to_s
		return @root + uuid if @hashdepth.zero?

		# Split the first 8 characters of the UUID up into subdirectories, one for 
		# each @hashdepth
		path = [ @root ]
		chunksize = 8 / @hashdepth
		0.step( 7, chunksize ) do |i|
			path << uuid[i, chunksize]
		end
		
		path << uuid
		return Pathname.new( File.join( *path ) )
	end


	### Yield a lock-protected IO object open for writing to the file that 
	### corresponds to +uuid+ to the supplied block.
	def open_writer( uuid )
		path = self.hashed_path( uuid )
		
		self.log.debug "Opening writer for %s" % [path]
		
		spoolfile = @root + @spooldir + uuid.to_s
		spoolfile.dirname.mkpath

		# open the spoolfile and a lock, link into place after write
		Lockfile.new( "#{ spoolfile }.lock", @lock_opts ) do
			io = spoolfile.open( File::CREAT|File::WRONLY|File::EXCL )
			self.log.debug "  locked %s" % [path]

			begin
				yield( io )
			rescue StandardError, Errno => err
				self.log.error "  %s during upload: %s" % [ err.class, err.message ]
				spoolfile.unlink
				raise
			else 
				path.dirname.mkpath
				spoolfile.rename( path )
				self.log.debug "  successfully uploaded file %s" % uuid
			ensure
				io.close unless io.closed?
			end
		end
	end


	### Return an IO object open for reading from the file that 
	### corresponds to +uuid+.
	def open_reader( uuid )
		path = self.hashed_path( uuid )
		return nil unless path.exist?

		self.log.debug "Opening reader for %s" % [path]
		
		return path.open( File::RDONLY )
	end


	#######
	private
	#######

	### Stat the files that are currently in the filestore and return the sum of 
	### their size.
	def find_filestore_size
		sum = 0
		
		self.log.info "Calculating current size of FileStore (this could take a moment...)"
		@root.find do |path|
			next unless path.file? && path.basename.to_s =~ /^#{UUID_REGEXP}$/
			sum += path.size
		end
		
		maxsize = @options[:maxsize] ? "%0.2fMB" % [@options[:maxsize]/ONE_MEGABYTE.to_f] : nil
		self.log.info "FileStore currently using %0.2fMB%s" %
			[sum / ONE_MEGABYTE.to_f, maxsize ? " of #{maxsize}" : "" ]
		
		return sum
	end
	
		
end # class ThingFish::FilesystemFileStore

# vim: set nosta noet ts=4 sw=4:

