#!/usr/bin/ruby
#
# ThingFish::RdfMetastore -- a metastore plugin for ThingFish that stores metadata in an
# RDF knowledgebase.
#
# == Synopsis
#
#   require 'thingfish/metastore'
#
#   ms = ThingFish::MetaStore.create( "rdf" )
#
#   ms.set_property( uuid, 'hands', 'buttery' )
#   ms.get_property( uuid, 'pliz_count' )			# => 2
#   ms.get_properties( uuid )						# => {...}
#
#   metadata = ms[ uuid ]
#   metadata.format = 'application/x-yaml'
#   metadata.format		# => 'application/x-yaml'
#   metadata.format?		# => true
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
# Please see the file LICENSE in the base directory for licensing details.
#

begin
	require 'pathname'
	require 'rdf/redland'
	require 'rdf/redland/constants'
	require 'uuidtools'

	require 'thingfish'
	require 'thingfish/exceptions'
	require 'thingfish/metastore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### ThingFish::RdfMetaStore-- a metastore plugin for ThingFish
class ThingFish::RdfMetaStore < ThingFish::MetaStore

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default root directory
	DEFAULT_ROOT = '/tmp/thingstore'


	### Various schemas for metadata
	module Schemas
		TF_SCHEMA = 'http://opensource.laika.com/rdf/2007/02/thingfish-schema#'
		TFNS = Redland::Namespace.new( TF_SCHEMA )
		
		UUID_URN = 'urn:uuid:'
		UUID_NS = Redland::Namespace.new( UUID_URN )
	end
	include Schemas
	

	### Proxy class for metadata operations for a given resource.
	class RdfResourceProxy < ThingFish::MetaStore::ResourceProxy
		include Enumerable
		
		### Create a new RdfResourceProxy for the given +uuid+ that will perform
		### operations on the given RDF +model+.
		def initialize( uuid, model )
			@uuid  = uuid
			@model = model
		end


		######
		public
		######

		# The associated UUID
		attr_reader :uuid


		### Enumerable interface: Call the supplied block once for each property
		### associated with the proxied resource.
		def each( &block )
			@model.get_properties( @uuid ).each( &block )
		end


		### Adds the contents of +hash+ to the values for the referenced UUID, overwriting entries
		### with duplicate keys.
		def update( hash )
			@store.update_properties( @uuid,  hash )
		end
		alias_method :merge!, :update
		

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
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new RdfMetaStore
	def initialize( options={} )
		@store = Redland::HashStore.new( 'memory', 'thingfish' )
		@model = Redland::Model.new( @store )
	end


	######
	public
	######


	### Return a RdfResourceProxy for the given +uuid+ that can used to get, set, and
	### query metadata about the resource associated with +uuid+.
	def []( uuid )
		
	end
	
	
	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		uri = UUID_NS[ uuid ]
		res = @model.get_resource( uri )
	end

	
	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ][ propname.to_sym ]
		end
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ].clone
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ].key?( propname.to_sym )
		end
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ] ||= {}
				return @metadata[ uuid.to_s ].delete( propname.to_sym ) ? true : false
			end
		end
	end
	
	
	### MetaStore API: Removes all properties from given +uuid+
	def delete_properties( uuid )
		@lock.lock do
			@metadata.transaction do
				return 0 if @metadata[ uuid.to_s ].nil?
				count = @metadata[ uuid.to_s ].length
				@metadata.delete( uuid.to_s )
				return count
			end
		end
	end

	### MetaStore API: Return all property keys in store
	def get_all_property_keys

		# PStore doesn't implement a collect(), so we need a manual collector.
		keys = []

		@lock.lock do
			@metadata.transaction(true) do
				@metadata.roots.each do |uuid|
					keys << @metadata[ uuid ].keys
				end
			end
		end
		return keys.flatten.uniq
	end
		
end # class ThingFish::RdfMetaStore

# vim: set nosta noet ts=4 sw=4:

