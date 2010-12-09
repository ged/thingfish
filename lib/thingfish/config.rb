#!/usr/bin/env ruby

require 'tmpdir'
require 'pathname'
require 'forwardable'
require 'yaml'
require 'logger'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/mixins'
require 'thingfish/utils'
require 'thingfish/filter'
require 'thingfish/filestore'
require 'thingfish/metastore'
require 'thingfish/urimap'

#
# The ThingFish config reader/writer class
#
# == Synopsis
#
#   require 'thingfish/config'
#
#   config = ThingFish::Config.load( "config.yml" )
#
#   host, port = config.host, config.port
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
class ThingFish::Config
	extend Forwardable

	include ThingFish::Constants,
	 	ThingFish::Loggable,
		ThingFish::HtmlInspectableObject


	# Define the layout and defaults for the underlying structs
	DEFAULTS = {
		:ip           => DEFAULT_BIND_IP,
		:port         => DEFAULT_PORT,
		:user         => nil,
		:datadir      => DEFAULT_DATADIR,
		:spooldir     => DEFAULT_SPOOLDIR,
		:bufsize      => DEFAULT_BUFSIZE,
	    :resource_dir => nil,

		:pipeline_max        => 100,
		:memory_bodysize_max => 100.kilobytes,
		:connection_timeout  => 30,

		:profiling => {
			:enabled            => false,
			:connection_enabled => false,
			:profile_dir        => DEFAULT_PROFILEDIR,
			:metrics            => []
		},

		:use_strict_html_mimetype => false,

		:daemon  => false,
		:pidfile => nil,
		:defaulthandler => {
			:html_index   => 'index.rhtml'
		},

		:plugins => {
			:filestore => {
				:name => 'memory',
			},
			:metastore => {
				:name => 'memory'
			},
			:urimap => {
				:'/metadata' => 'simplemetadata'
			},
			:filters => [ 'ruby' ],
		},

		:logging => {
			:logfile => 'stderr',
			:level => 'warn',
		}
	}
	DEFAULTS.freeze



	#############################################################
	###	C L A S S   M E T H O D S
	#############################################################

	### Read and return a ThingFish::Config object from the given file or
	### configuration source.
	def self::load( path )
		path = Pathname.new( path ).expand_path
		source = path.read
		return new( source, path )
	end


	### Recursive hash-merge function. Used as the block argument to a Hash#merge.
	def self::merge_complex_hashes( key, oldval, newval )
		return oldval.merge( newval, &method(:merge_complex_hashes) ) if
			oldval.is_a?( Hash ) && newval.is_a?( Hash )
		return newval
	end



	#############################################################
	###	I N S T A N C E   M E T H O D S
	#############################################################

	### Create a new ThingFish::Config object. If the optional +source+ argument
	### is specified, parse the config from it.
	def initialize( source=nil, name=nil, &block )

		if source
			@struct = self.make_configstruct_from_source( source )
		else
			confighash = Marshal.load( Marshal.dump(DEFAULTS) )
			@struct = ConfigStruct.new( confighash )
		end

		@spooldir_path   = nil
		@profiledir_path = nil
		@time_created    = Time.now
		@name            = name.to_s if name
		@handler_map     = {}

		self.instance_eval( &block ) if block
	end


	######
	public
	######

	# Define delegators to the inner data structure
	def_delegators :@struct, :to_hash, :to_h, :member?, :members, :merge,
		:merge!, :each, :[], :[]=

	# The underlying config data structure
	attr_reader :struct

	# The time the configuration was loaded
	attr_accessor :time_created

	# The name of the associated record stored on permanent storage for this
	# configuration.
	attr_accessor :name


	### Install any global parts of the current config
	def install
		if ThingFish.using_default_logger?
			logoutput = self.parsed_logfile
			level = self.parsed_logging_level

			ThingFish.logger = Logger.new( logoutput )
			ThingFish.logger.formatter =
				ThingFish::LogFormatter.new(
					ThingFish.logger,
					self.logging.format,
					self.logging.debug_format
				)
			ThingFish.logger.level = level
		end

		# Set the mimetype for HTML documents
		if self.use_strict_html_mimetype
			ThingFish::Constants.const_set( :CONFIGURED_HTML_MIMETYPE, XHTML_MIMETYPE )
		end
	end


	### Return the logfile specified as a string in the config as a file path or
	## an IO object.
	def parsed_logfile
		case self.logging.logfile
		when /^stdout$/i, /^defout$/i
			$stdout.sync = true
			return $stdout
		when /^stderr$/i, /^deferr$/i
			$stderr.sync = true
			return $stderr
		when %r{^/}
			return self.logging.logfile
		when nil
			return nil
		else
			raise ThingFish::ConfigError,
				"invalid logfile '%s': absolute path required" % [self.logging.logfile]
		end
	end


	### Return the logging level specified as a string in the config as an
	### integer compatible with the levels defined in the Logger class.
	def parsed_logging_level
		case self.logging.level
		when /^debug$/i
			return Logger::DEBUG
		when /^info$/i
			return Logger::INFO
		when /^warn$/i
			return Logger::WARN
		when /^error$/i
			return Logger::ERROR
		when /^fatal$/i
			return Logger::FATAL
		else
			raise ArgumentError, "Unknown logging level '%s'" % [self.logging.level]
		end
	end


	### Return a Pathname object for the directory that ThingFish will write all data to.
	def datadir_path
		 return Pathname.new( self.datadir )
	end


	### Return a Pathname object for the directory that temporary files should be created in.
	### If the config specifies a relative path, this will be relative to the +datadir+.
	def spooldir_path
		@spooldir_path ||= self.qualify_path( self.spooldir || DEFAULT_SPOOLDIR )
		return @spooldir_path
	end


	### Return a Pathname object for the directory that profiler reports should be saved in.
	### If the config specifies a relative path, this will be relative to the +datadir+.
	def profiledir_path
		@profiledir_path ||= self.qualify_path( self.profiling.profile_dir || DEFAULT_PROFILEDIR )
		return @profiledir_path
	end


	### Construct a fully-qualified Pathname object from the given +dir+, either as-is if it is
	### already an absolute path, or relative to the configured +datadir+ if not.
	def qualify_path( dir )
		sp = Pathname( dir )
		self.log.debug "Qualifying path %p with datadir %p" % [ sp, self.datadir ]
		return sp unless sp.relative?
		return Pathname( self.datadir ) + sp
	end


	### Set up the data and spool directories and return them
	def setup_data_directories
		self.log.debug "Ensuring the configured data directory (%s) exists" % [ self.datadir_path ]
		self.datadir_path.mkpath

		self.log.debug "Ensuring the configured spool directory (%s) exists" % [ self.spooldir_path ]
		self.spooldir_path.mkpath

		if self.profiling.enabled?
			self.log.debug "Ensuring the configured profile data directory (%s) exists" %
				[ self.profiledir_path ]
			self.profiledir_path.mkpath
		end
	end


	### Instantiate, configure, and return the filestore plugin specified by the
	### configuration.
	def create_configured_filestore
		options = self.plugins.filestore.to_hash
		name = options.delete( :name )
		self.log.info "Creating a %s filestore with options %p" % [ name, options ]

		return ThingFish::FileStore.create( name, self.datadir_path, self.spooldir_path, options )
	end


	### Instantiate, configure, and return the metastore plugin specified by the
	### configuration.
	def create_configured_metastore
		options = self.plugins.metastore.to_hash
		name = options.delete( :name )
		self.log.info "Creating a %s metastore with options %p" % [ name, options ]

		return ThingFish::MetaStore.create( name, self.datadir_path, self.spooldir_path, options )
	end


	### Instantiate, configure, and return the filter plugins specified by the
	### configuration.
	def create_configured_filters
		return self.plugins.filters.collect do |tuple|
			self.log.debug "Filter config tuple is: %p" % [ tuple ]
			name, options = *(Array( tuple ).first)
			self.log.info "Loading '%s' filter with options: %p" % [ name, options ]
			ThingFish::Filter.create( name.to_s, options || {} )
		end
	end


	### Instantiate, configure, and return the handler URI mapping as specified
    ### by the configuration.
	def create_configured_urimap
		urimap = ThingFish::UriMap.new

		# Create an instance of the default handler, with options dictated by the
		# specified +config+ object.
		default_options = { :resource_dir => self.resource_dir }
		if self.defaulthandler
			default_options.merge!( self.defaulthandler )
		end
		default_handler = ThingFish::Handler.create( 'default', '/', default_options )
		urimap.register( '/', default_handler )

		# Register each specified handler under the associated uri.
		self.each_handler_uri do |handler, uri|
			self.log.info "  registering %s at %p" % [ handler.class.name, uri ]
			urimap.register( uri, handler )
		end

		self.log.debug "URI map is: %p" % [ urimap ]
		return urimap
	end


	### Iterate over each configured handler, yielding the handler and uri to the
	### supplied block.
	def each_handler_uri
		raise LocalJumpError, "no block given" unless block_given?

		if self.plugins && self.plugins.urimap
			urimap = self.plugins.urimap.to_hash
			self.log.debug {"Creating %d configured handlers" % [urimap.length]}

			urimap.each do |path, handlers|
				path = path.to_s
				raise ThingFish::ConfigError, "key %p is not a path" % [ path ] unless
					path[0] == ?/
				path.sub!( %r{/$}, '' )

				# Convert map entries like:
				#    /foo: my_awesome_handler
				# into the same format as the more-complex style
				handlers = [{ handlers => {} }] unless handlers.is_a?( Array )

				# Create an instance of a handler for each one
				handlers.each do |handler_config|
					handler_config.each do |name, options|
						self.log.debug "Mapping %p to %p with options = %p" % [ name, path, options ]
						@handler_map[ name ] ||= path
						handler = ThingFish::Handler.create( name, path, options )
						yield( handler, path )
					end
				end
			end
		else
			self.log.warn "No handlers configured"
		end

		return urimap
	end


	### Return the first URI the specified +handler+ is installed at, if any. If
	### there is no such handler installed, returns nil.
	def find_handler_uri( handler )
		raise ThingFish::ConfigError, "handler map isn't populated yet" if @handler_map.empty?
		return @handler_map[ handler ]
	end


	### Return the config object as a YAML hash
	def dump
		strhash = stringify_keys( self.to_h )
		return YAML.dump( strhash )
	end


	### Write the configuration object using the specified name and any
	### additional +args+.
	def write( name=@name, *args )
		raise ArgumentError,
			"No name associated with this config." unless name
		File.open( name, File::WRONLY|File::CREAT|File::TRUNC ) do |ofh|
			ofh.print( self.dump )
		end
	end


	### Returns +true+ for methods which can be autoloaded
	def respond_to?( sym )
		self.log.debug "Checking response to %p message..." % [ sym ]
		key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym
		self.log.debug "  normalized key is: %p, struct members are: %p" % [ key, @struct.members ]
		return true if @struct.member?( key )
		super
	end


	### Returns +true+ if the configuration has changed since it was last
	### loaded, either by setting one of its members or changing the file
	### from which it was loaded.
	def changed?
		return self.changed_reason ? true : false
	end


	### If the configuration has changed, return the reason. If it hasn't,
	### returns nil.
	def changed_reason
		if @struct.modified?
			return "Struct was modified"
		end

		if self.name && self.is_older_than?( self.name )
			return "Config source (%s) has been updated since %s" %
				[ self.name, self.time_created ]
		end

		return nil
	end


	### Return +true+ if the specified +file+ is newer than the time the receiver
	### was created.
	def is_older_than?( file )
		return false unless File.exists?( file )
		st = File.stat( file )
		self.log.debug "File mtime is: %s, comparison time is: %s" %
			[ st.mtime, @time_created ]
		return st.mtime > @time_created
	end


	### Reload the configuration from the original source if it has
	### changed. Returns +true+ if it was reloaded and +false+ otherwise.
	def reload
		return false unless @name

		self.time_created = Time.now
		source = File.read( @name )
		@struct = self.make_configstruct_from_source( source )

		self.install
	end



	#########
	protected
	#########


	### Read in the specified +filename+ and return a
	### ThingFish::Config::ConfigStruct
	def make_configstruct_from_source( source )
		mergefunc = ThingFish::Config.method( :merge_complex_hashes )
		hash = YAML.load( source )
		ihash = symbolify_keys( untaint_values(hash) )
		mergedhash = DEFAULTS.merge( ihash, &mergefunc )
		self.log.debug "Configuration parsed as: %p" % [mergedhash]

		return ConfigStruct.new( mergedhash )
	end


	### Handle calls to struct-members
	def method_missing( sym, *args )
		key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym
		return nil unless @struct.member?( key )

		reader    = lambda { @struct[key] }
		writer    = lambda {|arg| @struct[key] = arg }
		predicate = lambda { @struct.send("#{key}?") }

		self.class.send( :define_method, key, &reader )
		self.class.send( :define_method, "#{key}=", &writer )
		self.class.send( :define_method, "${key}?", &predicate )

		return self.method( sym ).call( *args )
	end


	#######
	private
	#######

	### Return a copy of the specified +hash+ with all of its values
	### untainted.
	def untaint_values( hash )
		newhash = {}
		hash.each do |key,val|
			case val
			when Hash
				newhash[ key ] = untaint_values( hash[key] )

			when Array
				newval = val.collect {|v| v.dup.untaint}
				newhash[ key ] = newval

			when NilClass, TrueClass, FalseClass, Numeric, Symbol
				newhash[ key ] = val

			else
				newval = val.dup
				newval.untaint
				newhash[ key ] = newval
			end
		end
		return newhash
	end


	### Return a duplicate of the given +hash+ with its identifier-like keys
	### transformed into symbols from whatever they were before.
	def symbolify_keys( hash )
		newhash = {}
		hash.each do |key,val|
			if val.is_a?( Hash )
				newhash[ key.to_sym ] = symbolify_keys( val )
			else
				newhash[ key.to_sym ] = val
			end
		end

		return newhash
	end


	### Return a version of the given +hash+ with its keys transformed
	### into Strings from whatever they were before.
	def stringify_keys( hash )
		newhash = {}
		hash.each do |key,val|
			if val.is_a?( Hash )
				newhash[ key.to_s ] = stringify_keys( val )
			else
				newhash[ key.to_s ] = val
			end
		end

		return newhash
	end



	#############################################################
	###	I N T E R I O R   C L A S S E S
	#############################################################

	### Hash-wrapper that allows struct-like accessor calls on nested
	### hashes.
	class ConfigStruct
		include Enumerable,
		        ThingFish::Loggable
		extend Forwardable

		# Mask most of Kernel's methods away so they don't collide with
		# config values.
		Kernel.methods(false).each {|meth|
			next unless method_defined?( meth )
			next if /^(?:__|dup|object_id|inspect|class|raise|method_missing|log)/.match( meth )
			undef_method( meth )
		}

		# Forward some methods to the internal hash
		def_delegators :@hash, :keys, :key?, :values, :value?, :[], :[]=, :length,
		    :empty?, :clear


		### Create a new ConfigStruct from the given +hash+.
		def initialize( hash )
			@hash = hash.dup
			@dirty = false
		end


		######
		public
		######

		# Modification flag. Set to +true+ to indicate the contents of the
		# Struct have changed since it was created.
		attr_writer :modified


		### Return a human-readable representation of the object suitable for
		### debugging.
		def inspect
			default = super
			return "#<%p 0x%0x: %s (%s)>" % [
				self.class,
				self.object_id * 2,
				default,
				self.modified? ? "modified" : "not modified"
			]
		end


		### Returns +true+ if the ConfigStruct or any of its sub-structs
		### have changed since it was created.
		def modified?
			@dirty || @hash.values.find do |obj|
				obj.is_a?( ConfigStruct ) && obj.modified?
			end
		end


		### Return the receiver's values as a (possibly multi-dimensional)
		### Hash with String keys.
		def to_hash
			rhash = {}
			@hash.each {|k,v|
				case v
				when ConfigStruct
					rhash[k] = v.to_h
				when NilClass, FalseClass, TrueClass, Numeric
					# No-op (can't dup)
					rhash[k] = v
				when Symbol
					rhash[k] = v.to_s
				else
					rhash[k] = v.dup
				end
			}
			return rhash
		end
		alias_method :to_h, :to_hash


		### Return +true+ if the receiver responds to the given
		### method. Overridden to grok autoloaded methods.
		def respond_to?( sym, priv=false )
			raise "Chumba!"
			self.log.debug "Checking response to %p message..." % [ sym ]
			key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym
			self.log.debug "  normalized key is: %p, hash keys are: %p" % [ key, @hash.keys ]
			return true if @hash.key?( key )
			super
		end


		### Returns an Array of Symbols, one for each of the struct's members.
		def members
			@hash.keys
		end


		### Returns +true+ if the given +name+ is the name of a member of
		### the receiver.
		def member?( name )
			return @hash.key?( name.to_s.to_sym )
		end


		### Call into the given block for each member of the receiver.
		def each_section( &block ) # :yield: member, value
			@hash.each( &block )
		end
		alias_method :each, :each_section


		### Merge the specified +other+ object with this config struct. The
		### +other+ object can be either a Hash, another ConfigStruct, or an
		### ThingFish::Config.
		def merge!( other )
			mergefunc = ThingFish::Config.method( :merge_complex_hashes )

			case other
			when Hash
				@hash = self.to_h.merge( other, &mergefunc )

			when ConfigStruct
				@hash = self.to_h.merge( other.to_h, &mergefunc )

			when ThingFish::Config
				@hash = self.to_h.merge( other.struct.to_h, &mergefunc )

			else
				raise TypeError,
					"Don't know how to merge with a %p" % other.class
			end

			# :TODO: Actually check to see if anything has changed?
			@dirty = true

			return self
		end


		### Return a new ConfigStruct which is the result of merging the
		### receiver with the given +other+ object (a Hash or another
		### ConfigStruct).
		def merge( other )
			self.dup.merge!( other )
		end



		#########
		protected
		#########

		### Handle calls to key-methods
		def method_missing( sym, *args )
			key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym

			self.class.class_eval {
				define_method( key ) {
					if !@hash[ key] || @hash[ key ].is_a?( Hash )
						@hash[ key ] = ConfigStruct.new( @hash[key] )
					end

					@hash[ key ]
				}
				define_method( "#{key}?" ) {@hash[key] ? true : false}
				define_method( "#{key}=" ) {|val|
					@dirty = @hash[key] != val
					@hash[key] = val
				}
			}

			self.method( sym ).call( *args )
		end
	end # class ConfigStruct

end # class ThingFish::Config

# vim: set nosta noet ts=4 sw=4:

