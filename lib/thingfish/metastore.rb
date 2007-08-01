#!/usr/bin/ruby
# 
# The base metastore class for ThingFish
# 
# == Synopsis
# 
#   require 'thingfish/metastore'
#
#   class MyMetaStore < ThingFish::MetaStore
#       # ...
#   end
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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'pluginfactory'
require 'thingfish'
require 'thingfish/mixins'


### Base class for ThingFish MetaStore plugins
class ThingFish::MetaStore
	include PluginFactory,
	        ThingFish::Loggable,
	        ThingFish::AbstractClass


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	### Proxy class for metadata operations for a given resource.
	class ResourceProxy
		include Enumerable
		
		### Create a new ResourceProxy for the given +uuid+ that will perform
		### operations on the given +store+.
		def initialize( uuid, store )
			@uuid = uuid
			@store = store
		end

		######
		public
		######

		# The associated UUID
		attr_reader :uuid


		### Enumerable interface: Call the supplied block once for each property
		### associated with the proxied resource.
		def each( &block )
			@store.get_properties( @uuid ).each( &block )
		end


		### Returns true if the +other+ object is equivalent to the receiver
		### (they have the same UUID).
		def ==( other )
			self.uuid == other.uuid
		rescue MethodError
			return false
		end
		
		
		#########
		protected
		#########

		### Proxy method for calling methods that correspond to keys.
		def method_missing( sym, *args )
			case sym.to_s
			when /^(?:has_)(\w+)\?$/
				propname = $1
				return @store.has_property?( @uuid, propname )

			when /^(\w+)=$/
				propname = $1
				return @store.set_property( @uuid, propname, *args )
				
			else
				propname = sym.to_s
				return @store.get_property( @uuid, propname )
			end
		end
		
	end # class ResourceProxy

	

	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### PluginFactory interface: Return an Array of prefixes to use when searching 
	### for derivatives.
	def self::derivative_dirs
		['thingfish/metastore']
	end
	

	### PluginFactory interface: Return a sprintf string which describes the naming
	### convention of plugin gems for this class. The results will be used as an
	### argument to the 'Kernel::gem' function.
	def self::rubygem_name_pattern
		'thingfish-%sms'
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new ThingFish::MetaStore object.
	def initialize( options={} )
		@options = options
		@proxy_class = ResourceProxy
		super()
	end


	######
	public
	######

	# The class of object to use as the proxy for a given object's metadata
	attr_accessor :proxy_class
	
	
	### Return a ResourceProxy for the given +uuid+ that can used to get, set, and
	### query metadata about the resource associated with +uuid+.
	def []( uuid )
		raise ThingFish::PluginError,
			"%s did not call its parent class's initializer" % [self.class.name] unless
			@proxy_class
		return @proxy_class.new( uuid.to_s, self )
	end


	### Mandatory MetaStore API
	virtual :has_property?,
		:set_property,
		:get_property,
		:get_properties,
		:delete_property,
		:delete_properties,
		:get_all_property_keys


	### Extract a default set of metadata for the upload in the given +request+.
	def extract_default_metadata( uuid, request )
		metadata = self[ uuid ]
		now      = Time.now

		metadata.format        = request.params[ 'CONTENT_TYPE' ]
		metadata.extent        = request.params[ 'CONTENT_LENGTH' ]
		metadata.useragent     = request.params[ 'HTTP_USER_AGENT' ]
		metadata.uploadaddress = request.params[ 'REMOTE_ADDR' ]
		metadata.created       = now unless metadata.created
		metadata.modified      = now
	end
	


end # class ThingFish::MetaStore


# vim: set nosta noet ts=4 sw=4:

