#!/usr/bin/ruby
#
# A collection of mixins shared between ThingFish classes
#
# == Synopsis
#
#   require 'thingfish/mixins'
#
#   # Loggable
#   class MyClass
#       include ThingFish::Loggable
#
#       def foo
#           self.log.debug "something"
#       end
#   end
#
#   # StaticResourcesHandler
#   class MyHandler < ThingFish::Handler
#       include ThingFish::StaticResourcesHandler
#   
#       static_resource_dir "static"
#
#       # ...
#   end
#
#   # ResourceLoader
#   class MyMetastore < ThingFish::MetaStore
#       include ThingFish::ResourceLoader
#   
#       def initialize( options )
#           unless schema_installed?
#               sql = get_resource( 'base_schema.sql' )
#               install_schema( sql )
#           end
#           ...
#       end
#
#   end
#
#   # AbstractClass
#   class MyBaseClass
#       include ThingFish::AbstractClass
#   
#       # Define a method that will raise a NotImplementedError if called
#       virtual :api_method
#   end
#
#   # NumericConstantMethods
#   class Numeric
#       include ThingFish::NumericConstantMethods
#   end
#
# == Description
#
# This module includes a collection of mixins used in ThingFish classes. It currently
# contains:
#
# === ThingFish::Loggable
#
# Adds a #log method to the including class which can be used to access the global
# logging facility.
#
# === ThingFish::StaticResourcesHandler
#
# Adds the ability to a ThingFish::Handler to serve static content from its resources
# directory.
#
# === ThingFish::ResourceLoader
#
# Adds some methods that can be used to load content from files in a 
# resources directory.
#
# === ThingFish::AbstractClass
# 
# Hides your class's ::new method and adds a method generator called 'virtual' for
# defining API methods. If subclasses of your class don't provide implementations of
# "virtual" methods, NotImplementedErrors will be raised if they are called.
#
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
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'rbconfig'
require 'erb'

require 'thingfish'


module ThingFish # :nodoc:

	### Add logging to a ThingFish class
	module Loggable

		#########
		protected
		#########

		### Return the global logger.
		def log
			ThingFish.logger
		end

	end # module Loggable


	### Add the ability to serve static content from a ThingFish::Handler's resource
	### directory
	module StaticResourcesHandler
		
		### Inclusion callback -- add class methods to the including module.
		def self::included( mod )
			mod.extend( ClassMethods )
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


		### Hook the listener callback
		def listener=( listener )
			require 'thingfish/handler'
			super
			
			basedir = self.resource_dir + self.class.static_resources_dir
			self.log.debug "Serving static resources for %s from %s" % 
				[self.class.name, basedir.to_s]
			my_uris = self.find_handler_uris

			handler = ThingFish::Handler.create( 'staticcontent', basedir )
			my_uris.each do |uri|
				self.log.debug "...registering fallback %s for a %s at %p" %
				 	[ handler.class.name, self.class.name, uri ]
				listener.register( uri, handler )
			end
		end
	end # module StaticResourcesHandler
	
	
	### Add convenience methods for becoming a daemon and dropping privileges.
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
			[ $stdin, $stdout, $stderr ].each { |io| io.send( :reopen, '/dev/null' ) }
		end
		
		
		### Attempt to set the effective +uid+ to +username+.
		def become_user( username )
			self.log.debug "Dropping privileges (user: %s)" % [ username ]
			Process.euid = Etc.getpwnam( username ).uid
		end
	end
	
	
	### Adds some methods that can be used to load content from files in a 
	### resources directory.
	module ResourceLoader
		include ThingFish::Loggable,
		        ERB::Util

		### Set up the resource directory of the object
		def initialize( *args )
			@resource_dir = nil

			# Try to find the resource directory argument in the first Hash
			if options = args.find {|obj| obj.is_a?(Hash) }
				@resource_dir = options['resource_dir'] || options[:resource_dir]
			end

			if self.class.superclass.instance_method(:initialize).arity.zero?
				super()
			else
				super
			end
		end


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
			return self.class.name.
				sub( /ThingFish::/, '' ).
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
			self.log.debug "Making new ERB template from '%p' (%d bytes)" % 
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
	
	
	### Adds abstract class helpers to a class.
	module AbstractClass
		
		### Methods to be added to including classes
		module ClassMethods
			
			### Define one or more "virtual" methods which will raise 
			### NotImplementedErrors when called via a concrete subclass.
			def virtual( *syms )
				syms.each do |sym|
					define_method( sym ) {
						raise NotImplementedError,
							"%p does not provide an implementation of #%s" %
							[ self.class, sym ]
					}
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
	### ActiveSupport)
	module NumericConstantMethods

		### Time constants
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
		

		### Byte constants
		module Bytes
			
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

		end # module Bytes
	end # module NumericConstantMethods


end # module ThingFish

# vim: set nosta noet ts=4 sw=4:

