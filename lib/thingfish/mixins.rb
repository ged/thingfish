#!/usr/bin/env ruby

require 'rbconfig'
require 'erb'
require 'etc'

require 'thingfish'

#---
# A collection of mixins shared between ThingFish classes
#

module ThingFish


	### Adds a #log method to the including class which can be used to access the global
	### logging facility.
	###
	###   require 'thingfish/mixins'
	###
	###   class MyClass
	###       include ThingFish::Loggable
	###
	###       def foo
	###           self.log.debug "something"
	###       end
	###   end
	###
	module Loggable

		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		}

		### A logging proxy class that wraps calls to the logger into calls that include
		### the name of the calling class.
		class ClassNameProxy

			### Create a new proxy for the given +klass+.
			def initialize( klass, force_debug=false )
				@classname   = klass.name
				@force_debug = force_debug
			end

			### Delegate calls the global logger with the class name as the 'progname'
			### argument.
			def method_missing( sym, msg=nil, &block )
				return super unless LEVEL.key?( sym )
				sym = :debug if @force_debug
				ThingFish.logger.add( LEVEL[sym], msg, @classname, &block )
			end

		end # ClassNameProxy

		#########
		protected
		#########

		### Return the proxied logger.
		def log
			@log_proxy ||= ClassNameProxy.new( self.class )
		end

		### Return a proxied "debug" logger that ignores other level specification.
		def log_debug
			@log_debug_proxy ||= ClassNameProxy.new( self.class, true )
		end
	end # module Loggable


	### Adds some methods that can be used to load content from files in a
	### resources directory.
	###
	###   class MyMetastore < ThingFish::MetaStore
	###       include ThingFish::ResourceLoader
	###
	###       def initialize( options )
	###           @resource_dir = options['resource_dir']
	###           unless schema_installed?
	###               sql = self.get_resource( 'base_schema.sql' )
	###               self.install_schema( sql )
	###           end
	###           ...
	###       end
	###   end
	###
	module ResourceLoader
		include ThingFish::Loggable,
		        ERB::Util

		### Return a Pathname object that points at the resource directory
		### for this handler
		def resource_dir

			# If a resource dir hasn't been specified, figure out a reasonable default
			# using Ruby's datadir
			unless @resource_dir
				datadir = Pathname.new( ::Config::CONFIG['datadir'] )
				@resource_dir = datadir + 'thingfish' + self.plugin_name
			end

			return Pathname.new( @resource_dir )
		end


		### Return the normalized name of the including class, which
		### determines what the resources directory is named.
		def plugin_name
			classname = self.class.name or return 'anonymous'
			return classname.
				sub( /ThingFish::/, '' ).
				sub( /handler$/i, '' ).
				gsub( /\W+/, '-' ).
				downcase
		end


		#########
		protected
		#########

		### Return true if the specified resource exists
		def resource_exists?( path )
			resdir = self.resource_dir or
				raise "No resource directory available"
			resource = resdir + path
			return resource.exist?
		end


		### Return true if the specified directory exists under the resource
		### directory.
		def resource_directory?( path )
			resdir = self.resource_dir or
				raise "No resource directory available"
			resource = resdir + path
			return resource.directory?
		end


		### Read the content from the file
		def get_resource( path )
			return self.get_resource_io( path ).read
		end


		### Load the specified +resource+ as an ERB template and return it.
		def get_erb_resource( resource )
			source = self.get_resource( resource )
			self.log.debug "Making new ERB template from %p (%d bytes)" %
				[resource, source.length]
			return ERB.new( source )
		end


		### Return an IO object opened to the file specified by +path+
		### relative to the plugin's resource directory.
		def get_resource_io( path )
			resdir = self.resource_dir or
				raise "No resource directory available"
			self.log.debug "Trying to open resource %p from %s" % [ path, resdir ]
			( resdir + path ).open( File::RDONLY )
		end

	end # module ResourceLoader


	### Adds the ability to a ThingFish::Handler to serve static content from its resources
	### directory.
	###
	###   class MyHandler < ThingFish::Handler
	###       include ThingFish::StaticResourcesHandler
	###
	###       static_resource_dir "static"
	###
	###       # ...
	###   end
	###
	module StaticResourcesHandler

		### Inclusion callback -- add class methods to the including module.
		def self::included( mod )

			# Add our class method and the resource loader mixin to including classes
			mod.extend( ClassMethods )
			mod.send( :include, ResourceLoader )
			super
		end

		### Methods installed in including classes
		module ClassMethods

			### Set the directory which will be considered the root for all static
			### content requests.
			def static_resources_dir( dir=nil )
				if dir
					@static_resources_dir = dir
				end
				return defined?( @static_resources_dir ) ? @static_resources_dir : "static"
			end
		end


		### Register the static handler as a fallback for the including handler when it
		### is registered with the +daemon+.
		def on_startup( daemon )
			require 'thingfish/handler'
			super

			basedir = self.resource_dir + self.class.static_resources_dir
			self.log.debug "Serving static resources for %s from %s" %
				[self.class.name, basedir.to_s]

			handler = ThingFish::Handler.create( 'staticcontent', @path, basedir )
			self.log.debug "...registering fallback %s for a %s at %p" %
			 	[ handler.class.name, self.class.name, @path ]
			daemon.urimap.register_first( @path, handler )
		end
	end # module StaticResourcesHandler


	### Add convenience methods for becoming a daemon and dropping privileges.
	###
	###   class MyNewServer
	###       include Daemonizable
	###
	###       def run
	###           self.become_user( 'daemon' )
	###           self.daemonize( '/var/run/mynewserver.pid' )
	###       end
	###   end
	module Daemonizable

		private

		### Become a daemon, doing all the things a good daemon does.
		### TODO:  Not sure how to adequately test anything involving fork()...
		def daemonize( pidfile=nil )
			if ! pidfile.nil? && File.exists?( pidfile )
				self.log.warn "Stale pidfile found (%s)" % [ pidfile ]
			end

			self.log.info "Detaching from terminal and daemonizing..."
			fork and exit
			Process.setsid

			if ( pid = fork )
				# parent, write pidfile if required
				unless pidfile.nil?
					File.open( pidfile, 'w' ) do |pidfile|
						pidfile.puts pid
					end
				end
				exit
			end

			at_exit do
				File.delete( pidfile ) if File.exist?( pidfile )
			end

			Dir.chdir('/')
			File.umask(0)
			[ $stdin, $stdout, $stderr ].each {|io| io.send( :reopen, '/dev/null' ) }
		end


		### Attempt to set the effective +uid+ to +username+.
		def become_user( username )
			self.log.debug "Dropping privileges (user: %s)" % [ username ]
			Process.euid = Etc.getpwnam( username ).uid
		end
	end


	### Hides your class's ::new method and adds a method generator called 'virtual' for
	### defining API methods. If subclasses of your class don't provide implementations of
	### "virtual" methods, NotImplementedErrors will be raised if they are called.
	###
	###   # AbstractClass
	###   class MyBaseClass
	###       include ThingFish::AbstractClass
	###
	###       # Define a method that will raise a NotImplementedError if called
	###       virtual :api_method
	###   end
	###
	module AbstractClass

		### Methods to be added to including classes
		module ClassMethods

			### Define one or more "virtual" methods which will raise
			### NotImplementedErrors when called via a concrete subclass.
			def virtual( *syms )
				syms.each do |sym|
					define_method( sym ) do |*args|
						raise ::NotImplementedError,
							"%p does not provide an implementation of #%s" % [ self.class, sym ],
							caller(1)
					end
				end
			end


			### Turn subclasses' new methods back to public.
			def inherited( subclass )
				subclass.module_eval { public_class_method :new }
				super
			end

		end # module ClassMethods


		extend ClassMethods

		### Inclusion callback
		def self::included( mod )
			super
			if mod.respond_to?( :new )
				mod.extend( ClassMethods )
				mod.module_eval { private_class_method :new }
			end
		end


	end # module AbstractClass


	### A collection of methods to add to Numeric for convenience (stolen from
	### ActiveSupport), split into ThingFish::NumericConstantMethods::Time and
	### ThingFish::NumericConstantMethods::Bytes.
	###
	### This module is added to Numeric in lib/thingfish/monkeypatches.rb
	module NumericConstantMethods

		### A collection of convenience methods for calculating times using
		### Numeric objects:
		###
		###   # Add convenience methods to Numeric objects
		###   class Numeric
		###       include ThingFish::NumericConstantMethods::Time
		###   end
		###
		###   irb> 138.seconds.ago
		###       ==> Fri Aug 08 08:41:40 -0700 2008
		###   irb> 18.years.ago
		###       ==> Wed Aug 08 20:45:08 -0700 1990
		###   irb> 2.hours.before( 6.minutes.ago )
		###       ==> Fri Aug 08 06:40:38 -0700 2008
		###
		module Time

			### Number of seconds (returns receiver unmodified)
			def seconds
				return self
			end
			alias_method :second, :seconds

			### Returns number of seconds in <receiver> minutes
			def minutes
				return self * 60
			end
			alias_method :minute, :minutes

			### Returns the number of seconds in <receiver> hours
			def hours
				return self * 60.minutes
			end
			alias_method :hour, :hours

			### Returns the number of seconds in <receiver> days
			def days
				return self * 24.hours
			end
			alias_method :day, :days

			### Return the number of seconds in <receiver> weeks
			def weeks
				return self * 7.days
			end
			alias_method :week, :weeks

			### Returns the number of seconds in <receiver> fortnights
			def fortnights
				return self * 2.weeks
			end
			alias_method :fortnight, :fortnights

			### Returns the number of seconds in <receiver> months (approximate)
			def months
				return self * 30.days
			end
			alias_method :month, :months

			### Returns the number of seconds in <receiver> years (approximate)
			def years
				return (self * 365.25.days).to_i
			end
			alias_method :year, :years


			### Returns the Time <receiver> number of seconds before the
			### specified +time+. E.g., 2.hours.before( header.expiration )
			def before( time )
				return time - self
			end


			### Returns the Time <receiver> number of seconds ago. (e.g.,
			### expiration > 2.hours.ago )
			def ago
				return self.before( ::Time.now )
			end


			### Returns the Time <receiver> number of seconds after the given +time+.
			### E.g., 10.minutes.after( header.expiration )
			def after( time )
				return time + self
			end

			# Reads best without arguments:  10.minutes.from_now
			def from_now
				return self.after( ::Time.now )
			end
		end # module Time


		### A collection of convenience methods for calculating bytes using
		### Numeric objects:
		###
		###   # Add convenience methods to Numeric objects
		###   class Numeric
		###       include ThingFish::NumericConstantMethods::Bytes
		###   end
		###
		###   irb> 14.megabytes
		###       ==> 14680064
		###   irb> 188.gigabytes
		###       ==> 201863462912
		###   irb> 177263661663.size_suffix
		###       ==> "165.1G"
		###
		module Bytes

			# Bytes in a Kilobyte
			KILOBYTE = 1024

			# Bytes in a Megabyte
			MEGABYTE = 1024 ** 2

			# Bytes in a Gigabyte
			GIGABYTE = 1024 ** 3


			### Number of bytes (returns receiver unmodified)
			def bytes
				return self
			end
			alias_method :byte, :bytes

			### Returns the number of bytes in <receiver> kilobytes
			def kilobytes
				return self * 1024
			end
			alias_method :kilobyte, :kilobytes

			### Return the number of bytes in <receiver> megabytes
			def megabytes
				return self * 1024.kilobytes
			end
			alias_method :megabyte, :megabytes

			### Return the number of bytes in <receiver> gigabytes
			def gigabytes
				return self * 1024.megabytes
			end
			alias_method :gigabyte, :gigabytes

			### Return the number of bytes in <receiver> terabytes
			def terabytes
				return self * 1024.gigabytes
			end
			alias_method :terabyte, :terabytes

			### Return the number of bytes in <receiver> petabytes
			def petabytes
				return self * 1024.terabytes
			end
			alias_method :petabyte, :petabytes

			### Return the number of bytes in <receiver> exabytes
			def exabytes
				return self * 1024.petabytes
			end
			alias_method :exabyte, :exabytes

			### Return a human readable file size.
			def size_suffix
				bytes = self.to_f
				return case
					when bytes >= GIGABYTE then sprintf( "%0.1fG", bytes / GIGABYTE )
					when bytes >= MEGABYTE then sprintf( "%0.1fM", bytes / MEGABYTE )
					when bytes >= KILOBYTE then sprintf( "%0.1fK", bytes / KILOBYTE )
					else "%db" % [ self ]
					end
			end

		end # module Bytes

	end # module NumericConstantMethods


	### Add a #to_html method to the including object that is capable of dumping its
	### state as an HTML fragment.
	###
	###   class MyObject
	###       include HtmlInspectableObject
	###   end
	###
	###   irb> MyObject.new.html_inspect
	###      ==> "<span class=\"immediate-object\">#&lt;MyObject:0x56e780&gt;</span>"
	module HtmlInspectableObject

		### Return the receiver as an HTML fragment.
		def html_inspect
			return make_html_for_object( self )
		end


		#######
		private
		#######

		THREAD_DUMP_KEY = :__to_html_cache__

		HASH_HTML_CONTAINER = %{<div class="hash-members">%s</div>}
		HASH_PAIR_HTML = %{<div class="hash-pair"><div class="key">%s</div>} +
			%{<div class="value">%s</div></div>\n}
		ARRAY_HTML_CONTAINER = %{<ol class="array-members"><li>%s</li></ol>}
		IMMEDIATE_OBJECT_HTML_CONTAINER = %{<span class="immediate-object">%s</span>}


		### Return an HTML fragment describing the specified +object+.
		def make_html_for_object( object )
			object_html = []

			case object
			when Hash
				object_html << "\n<!-- Hash -->\n"
				if object.empty?
					object_html << '{}'
				else
					object_html << HASH_HTML_CONTAINER % [
						object.collect {|k,v|
							HASH_PAIR_HTML % [make_html_for_object(k), make_html_for_object(v)]
						}
					]
				end

			when Array
				object_html << "\n<!-- Array -->\n"
				if object.empty?
					object_html << '[]'
				else
					object_html << ARRAY_HTML_CONTAINER % [
						object.collect {|o| make_html_for_object(o) }.join('</li><li>')
					]
				end

			else
				if object.instance_variables.empty?
					return IMMEDIATE_OBJECT_HTML_CONTAINER % [ escape_html(object.inspect) ]
				else
					object_html << make_object_html_wrapper( object )
				end
			end

			return object_html.join("\n")
		end


		OBJECT_HTML_CONTAINER = %{<div id="object-%d" class="object %s">%s</div>}
		IVAR_HTML_FRAGMENT = %Q{
		  <div class="instance-variable">
			<div class="name">%s</div>
			<div class="value">%s</div>
		  </div>
		}


		### Wrap up the various parts of a complex object in an HTML fragment. If the
		### object has already been wrapped, returns a link to the previous rendering
		### instead.
		def make_object_html_wrapper( object )

			# If the object has been rendered already, just return a link to the previous
			# HTML fragment
			Thread.current[ THREAD_DUMP_KEY ] ||= {}
			if Thread.current[ THREAD_DUMP_KEY ].key?( object.object_id )
				return %Q{<a href="#object-%d" class="cache-link" title="jump to previous details">%s</a>} % [
					object.object_id,
					%{&rarr; %s #%d} % [ object.class.name, object.object_id ]
				]
			else
				Thread.current[ THREAD_DUMP_KEY ][ object.object_id ] = true
			end

			# Assemble the innards as an array of parts
			parts = [
				%{<div class="object-header">},
				%{<span class="object-class">#{object.class.name}</span>},
				%{<span class="object-id">##{object.object_id}</span>},
				%{</div>},
				%{<div class="object-body">},
			]

			object.instance_variables.each do |ivar|
				html = make_html_for_object( object.instance_variable_get(ivar) )
				parts << IVAR_HTML_FRAGMENT % [ ivar, html ]
			end

			parts << %{</div>}

			# Make HTML class names out of the object's namespaces
			namespaces = object.class.name.downcase.split(/::/)
			classes = []
			namespaces.each_index do |i|
				classes << namespaces[0..i].join('-') + '-object'
			end

			# Glue the whole thing together and return it
			return OBJECT_HTML_CONTAINER % [
				object.object_id,
				classes.join(" "),
				parts.join("\n")
			]
		end


		### Return the specifed +str+ with all HTML entities escaped.
		def escape_html( str )
			return str.
				gsub( /&/, '&amp;' ).
				gsub( /</, '&lt;' ).
				gsub( />/, '&gt;' )
		end

	end # module HtmlInspectableObject


end # module ThingFish

# vim: set nosta noet ts=4 sw=4:

