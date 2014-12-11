#!/usr/bin/env ruby

require 'tmpdir'
require 'pathname'
require 'lockfile'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/filestore'
require 'thingfish/mixins'


class Lockfile
	include ThingFish::Loggable
	
	def trace( s = nil )
		self.log.debug( s ? s : yield )
	end
end

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
#
# === Config Keys
#
# [+hashdepth+]
#   The number of subdirectories to use. Can be set to 1, 2, 4, or 8. Defaults to
#   ThingFish::FilesystemFileStore::DEFAULT_HASHDEPTH.
# [+bufsize+]
#   The size of the buffer to use when reading incoming data (in bytes). Defaults to
#   ThingFish::FilesystemFileStore::DEFAULT_BUFSIZE.
# [+cachesizes+]
#   Maintain total sizes in top level hash directories? Defaults to
#   ThingFish::FilesystemFileStore::DEFAULT_CACHESIZES
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
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::FilesystemFileStore < ThingFish::FileStore
	include ThingFish::Constants,
		ThingFish::Constants::Patterns

	# Number of bytes in one megabyte
	ONE_MEGABYTE = 1.megabyte

	# The default number of hashed directories
	DEFAULT_HASHDEPTH = 4

	# The buffer chunker size
	DEFAULT_BUFSIZE = 8192

	# Store hashdir sizes in each top level hashdir?
	DEFAULT_CACHESIZES = false

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
		:debug			=> true,
	}



	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new FilesystemFileStore
	def initialize( datadir, spooldir, options={} )
		raise ArgumentError, "invalid data directory %p" % [ datadir ] unless
			datadir.is_a?( Pathname )
		raise ArgumentError, "invalid spool directory %p" % [ spooldir ] unless
			spooldir.is_a?( Pathname )

		# Create the data directories if they don't already exist
		datadir.mkpath
		spooldir.mkpath

		super

		@hashdepth  = options[:hashdepth]  || DEFAULT_HASHDEPTH
		@bufsize    = options[:bufsize]    || DEFAULT_BUFSIZE
		@lock_opts  = options[:locking]    || DEFAULT_LOCKING_OPTIONS
		@cachesizes = options[:cachesizes] || DEFAULT_CACHESIZES

		raise ThingFish::ConfigError, "Max hash depth (8) exceeded" if @hashdepth > 8
		raise ThingFish::ConfigError, "Hash depth must be 1, 2, 4, or 8." \
			unless [ 1, 2, 4, 8 ].include?( @hashdepth )

		@total_size = 0
	end



	######
	public
	######

	# The number of hashed subdirectories to use
	attr_reader :hashdepth


	### Perform any startup tasks that should take place after the daemon has an opportunity
	### to daemonize and switch effective user.
	def on_startup
		@total_size = self.find_filestore_size if @options[:maxsize]
	end


	### Mandatory FileStore interface

	### FileStore API: write the specified +data+ to the store at the given +uuid+.
	def store( uuid, data )
		raise ThingFish::FileStoreQuotaError, "FileStore quota limit exceeded" if
		@options[:maxsize] && @total_size + data.length > @options[:maxsize]

		path = self.open_writer( uuid ) do |fh|
			fh.write( data )
		end

		self.log.info "Wrote %d bytes." % [ data.length ]
		self.update_size( path, data.length )
		return Digest::MD5.hexdigest( data )
	end


	### FileStore API: Store the data read from the given +io+ in the store at the given +uuid+.
	def store_io( uuid, io )
		maxsize = @options[:maxsize]
		uploadsize = 0

		digest = Digest::MD5.new
		path = self.open_writer( uuid ) do |fh|

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

		self.log.info "Wrote %d bytes (buffered)." % [ uploadsize ]
		self.update_size( path, uploadsize )
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


	### FileStore API: delete the data in the store at the given +uuid+.
	def delete( uuid )
		path = self.hashed_path( uuid )
		bytes = path.size
		if path.unlink
			self.update_size( path, -bytes )
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
		return @datadir + uuid if @hashdepth.zero?

		# Split the first 8 characters of the UUID up into subdirectories, one for
		# each @hashdepth
		path = [ @datadir ]
		chunksize = 8 / @hashdepth
		0.step( 7, chunksize ) do |i|
			path << uuid[i, chunksize]
		end

		path << uuid
		return Pathname.new( File.join( *path ) )
	end


	### Yield a lock-protected IO object open for writing to the file that
	### corresponds to +uuid+ to the supplied block.  Returns a Pathname
	### object to the file.
	def open_writer( uuid )
		path = self.hashed_path( uuid )

		self.log.debug "Opening writer for %s" % [path]

		spoolfile = @datadir + @spooldir + uuid.to_s
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

		return path
	end


	### Return an IO object open for reading from the file that
	### corresponds to +uuid+.
	def open_reader( uuid )
		path = self.hashed_path( uuid )
		return nil unless path.exist?

		self.log.debug "Opening reader for %s" % [path]

		return path.open( File::RDONLY )
	end


	### Given a +filepath+ as a Pathname object, modify the total_size
	### accessor and the size cache file by +amt+.  Don't perform any
	### updates if size caching is disabled. Returns the updated +@total_size+.
	###
	def update_size( filepath, amt )

		@total_size += amt

		if @cachesizes
			scache = self.sizecache( filepath )

			Lockfile.new( "#{ scache }.lock", @lock_opts ) do
				newsize = scache.exist? ? scache.read.to_i + amt : amt

				scache.open('w') do |fh|
					fh.write( newsize )
				end
			end
		end

		return @total_size
	end


	### Given a +filepath+ Pathname object to a resource,
	### return a Pathname to the size cache file responsible for it.
	###
	### This will store .size files in the uppermost hashed directory, i.e.:
	###		datadir/66f67ce6    --> datadir/66f67ce6/.size
	###		datadir/66f6/7ce6   --> datadir/66f6/.size
	###		datadir/66/f6/7c/e6 --> datadir/66/.size
	###
	def sizecache( filepath )
		dir = (1..@hashdepth - 1).inject( filepath.dirname ) {|pn, _| pn.parent }
		return dir + '.size'
	end


	### Find all previously generated size cache files.  Return a hash
	### of Pathname keys and size values.
	###
	def get_sizecache_files
		cachefiles = {}

		Pathname.glob( "#{@datadir}/*/.size" ) do |scache|
			cachefiles[ scache ] = scache.read.to_i
		end

		return cachefiles
	end


	### Stat the files that are currently in the filestore and return the sum of
	### their size.  Build cache files if enabled in the configuration for speedier
	### future startup times.
	###
	def find_filestore_size
		sum = 0
		cachefiles = self.get_sizecache_files

		self.log.info "Calculating current size of FileStore (this could take a moment...)"

		# If caching is configured and there are cache files, use them instead
		# of traversing the entirety of the filestore.
		#
		if @cachesizes and ! cachefiles.empty?
			self.log.debug 'Using filestore cache to determine total size...'
			sum = cachefiles.values.inject {|sum, val| sum + val }
		end

		# Remove cache files if they exist and caching is disabled, since the files
		# won't be maintained.
		#
		unless @cachesizes or cachefiles.empty?
			self.log.debug 'Removing previously cached filestore size files'
			cachefiles.each_key {|file| file.unlink }
		end

		# We don't have a sum, which means we either don't have caching enabled or we
		# need to generate the cache files. (First run.)  In any event, traverse the
		# whole filestore.
		#
		if sum.zero?
			self.log.debug 'Traversing filestore to determine total size...'
			@datadir.find do |path|
				next unless path.file? && path.basename.to_s =~ /^#{UUID_REGEXP}$/
					size = path.size
				sum += size

				# generate/update cache file
				self.update_size( path, size )
			end
		end

		maxsize = @options[:maxsize] ? "%0.2fMB" % [@options[:maxsize]/1.megabyte.to_f] : nil
		self.log.info "FileStore currently using %0.2fMB%s" %
		[sum / 1.megabyte.to_f, maxsize ? " of #{maxsize}" : "" ]

		return sum
	end

end # class ThingFish::FilesystemFileStore

# vim: set nosta noet ts=4 sw=4:

