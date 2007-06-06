#!/usr/bin/ruby
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
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
#
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'pathname'
require 'forwardable'
require 'yaml'
require 'logger'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/mixins'


### The configuration reader/writer class for ThingFish::Daemon.
class ThingFish::Config
	extend Forwardable
	include ThingFish::Constants, ThingFish::Loggable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# Define the layout and defaults for the underlying structs
	DEFAULTS = {
		:ip      => DEFAULT_BIND_IP,
		:port    => DEFAULT_PORT,
		:defaulthandler => {
		    :html_index => 'index.html',
		    :resource_dir => nil,
		},
		:plugins => {
			:filestore => {
				:name => 'memory',
			},
			:metastore => {
				:name => 'memory',
				:extractors => [],
			},
			:handlers => [],
			:filters => [],
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
	def initialize( source=nil, name=nil )

		if source
			@struct = self.make_configstruct_from_source( source )
		else
			confighash = DEFAULTS.dup
			@struct = ConfigStruct.new( confighash )
		end

		@time_created = Time.now
		@name = name.to_s if name
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
			ThingFish.logger.level = level
		end
	end


	### Return the logfile specified as a string in the config as a file path or
	## an IO object.
	def parsed_logfile
		case self.logging.logfile
		when /^stdout$/i, /^defout$/i
			return $defout
		when /^stderr$/i, /^deferr$/i
			return $deferr
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


	### Instantiate, configure, and return the filestore plugin specified by the
	### configuration.
	def create_configured_filestore
		options = self.plugins.filestore.to_hash
		name = options.delete( :name )
		self.log.info "Creating a %s filestore with options %p" % [ name, options ]
		
		return ThingFish::FileStore.create( name, options )
	end
	

	### Instantiate, configure, and return the metastore plugin specified by the
	### configuration.
	def create_configured_metastore
		options = self.plugins.metastore.to_hash
		name = options.delete( :name )
		self.log.info "Creating a %s metastore with options %p" % [ name, options ]
		
		return ThingFish::MetaStore.create( name, options )
	end
	

	### Iterate over each configured handler, yielding the handler and uri to the
	### supplied block.
	def each_handler_uri
		raise LocalJumpError, "no block given" unless block_given?

		if self.plugins && self.plugins.handlers
			raise ThingFish::ConfigError, "Invalid handlers config; should be an Array" unless
				self.plugins.handlers.is_a?( Array )
			self.log.debug {"Creating %d configured handlers" % [self.plugins.handlers.nitems]}

			self.plugins.handlers.reverse.each do |handler_config|
				name, uris, options = self.parse_handler_config( handler_config )
				handler = ThingFish::Handler.create( name, options )

				uris.each do |uri|
					yield( handler, uri )
				end
			end
		else
			self.log.debug "No handlers configured"
		end

		return self.plugins.handlers
	end


	### Parse the given +name+ and +config+, and return the name of the handler 
	### plugin and any configured URIs. The config can be a single URI string, an 
	### Array of URI strings, or a Hash with one or more URIs in its 'uris' pair. If 
	### a Hash is specified, it will also be passed to the plugin's constructor as 
	### options.
	def parse_handler_config( config )
		name, options = config.to_a.first
		self.log.debug "Handler config %s options parsed as %p" % [ name, options ]

		case options

		# - handlerName: /uri
		when String
			return name, Array(options), {}

		# - handlerName: [/uri, /uri2]
		when Array
			return name, options, {}

		# - handlerName:
		#		uris: [/uri, /uri2]
		#		option1: value
		#		option2: value
		when Hash
			raise ThingFish::ConfigError, "missing uris key for handler '%s'" % [name] \
				unless options.key?('uris')

			options['uris'] = Array( options['uris'] )
			return name, options['uris'], options

		else
			raise ThingFish::ConfigError, "invalid value %p for handler config" % [options]
		end

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
		return true if @struct.member?( sym.to_s.sub(/(=|\?)$/, '').to_sym )
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

		self.class.class_eval %{
			def #{key}; @struct.#{key}; end
			def #{key}=(*args); @struct.#{key} = *args; end
			def #{key}?; @struct.#{key}?; end
		}

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
		include Enumerable
		extend Forwardable

		# Mask most of Kernel's methods away so they don't collide with
		# config values.
		Kernel.methods(false).each {|meth|
			next unless method_defined?( meth )
			next if /^(?:__|dup|object_id|inspect|class|raise|method_missing)/.match( meth )
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
			key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym
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
			return nil unless @hash.key?( key )

			self.class.class_eval {
				define_method( key ) {
					if @hash[ key ].is_a?( Hash )
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

			self.__send__( sym, *args )
		end
	end # class ConfigStruct

end # class ThingFish::Config

# vim: set nosta noet ts=4 sw=4:

