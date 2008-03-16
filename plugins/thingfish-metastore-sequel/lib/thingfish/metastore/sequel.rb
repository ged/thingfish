#!/usr/bin/ruby
#
# ThingFish::SequelMetaStore-- a metastore plugin for ThingFish.
#
# == Synopsis
#
#   require 'thingfish/metastore'
#
#	# Postgres backend
#   ms = ThingFish::MetaStore.create(
#		"sequel", :sequel_connect => 'postgres://user:password@host/database'
#  	)
#
#   # SQLite memory backend
#   ms = ThingFish::MetaStore.create( 'sequel' )
#
#   ms.set_property( uuid, 'hands', 'buttery' )
#   ms.get_property( uuid, 'pliz_count' )			# => 2
#   ms.get_properties( uuid )						# => {...}
#
#   metadata = ms[ uuid ]
#   metadata.format		# => 'application/x-yaml'
#   metadata.format = 'application/x-yaml'
#   metadata.format?	# => true
#
# == Version
#
#  $Id$
#
# == Authors
#
#  * Michael Granger <mgranger@laika.com>
#  * Mahlon E. Smith <mahlon@laika.com>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

require 'forwardable'
require 'pathname'
require 'sequel'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/metastore/simple'


### A metastore backend that stores metadata tuples in a database,
### accessed via the Sequel library.
class ThingFish::SequelMetaStore < ThingFish::SimpleMetaStore

	extend Forwardable
	include ThingFish::Loggable

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new SequelMetaStore
	def initialize( options={} )
		super

		# Connect to the backend database specified in the
		# thingfish config file. ('sequel_connect')
		#
		#	sqlite:////tmp/thingfish/metastore.db
		#	postgres://user:password@host/database
		#	...
		#
		# Defaults to in-memory sqlite.
		#
		@metadata = options[:sequel_connect].nil? ?
					Sequel.sqlite :
					Sequel.open( options[:sequel_connect] )

		# Enable query logging in debug mode
		self.log.debug {
			@metadata.logger = self.log_debug
			'Enabled SQL query logging'
		}

		self.init_db
	end

	# The Sequel object that is backing the metastore
	attr_reader :metadata

	# Delegate transactions to the underlying Sequel object.
	def_delegators :@metadata, :transaction
	


	######
	public
	######


	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		r_id = get_id( :resources, uuid )
		m_id = get_id( :metakey, propname )

		if @metadata[ :metaval ].
				filter( :r_id => r_id, :m_id => m_id ).
				update( :val => value.to_s ).zero?
			@metadata[ :metaval ] << [ r_id, m_id, value.to_s ]
		end
	end

	
	### MetaStore API: Set the properties associated with the given +uuid+ to those
	### in the provided +propshash+.
	def set_properties( uuid, propshash )
		self.transaction do
			
			# Wipe existing properties
			@metadata[ :metaval ].
				filter( :r_id => @metadata[ :resources ].
						filter( :uuid => uuid.to_s ).select( :id ) ).delete
			propshash.each do |prop, val|
				self.set_property( uuid, prop, val )
			end
		end
	end
	

	### MetaStore API: Merge the provided +propshash+ into the properties associated with the 
	### given +uuid+.
	def update_properties( uuid, propshash )
		self.transaction do
			propshash.each do |prop, val|
				self.set_property( uuid, prop, val )
			end
		end		
	end
	
	
	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		props = self.get_properties( uuid )
		return props[ propname.to_sym ]
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		r_id = get_id( :resources, uuid )
		return @metadata[ :resources, :metakey, :metaval ].
			filter( :metakey__id   => :metaval__m_id,
					:resources__id => :metaval__r_id, 
					:metaval__r_id => r_id ).
			select( :metakey__key, :metaval__val ).inject({}) do |hash, row|
				
			hash[ row[:key].to_sym ] = row[:val]
			hash
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ exists in the metastore.
	def has_uuid?( uuid )
		return @metadata[ :resources ].
			filter( :uuid => uuid.to_s ).
			select( :id ).first.nil? ? false : true
	end
	
	
	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		return get_property( uuid, propname ) != nil
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		self.delete_properties( uuid, propname )
	end
	
	
	### MetaStore API: Removes the properties specified by +propnames+ from those
	### associated with +uuid+.
	def delete_properties( uuid, *propnames )
		r  = @metadata[ :resources ]
		mv = @metadata[ :metaval ]
		mk = @metadata[ :metakey ]
		props = propnames.collect { |prop| prop.to_s }

		mv.filter { :r_id == r.filter( :uuid => uuid.to_s ).select( :id ) &&
					:m_id == mk.filter( :key => props ).select( :id ) }.delete
	end
	
	
	### MetaStore API: Removes all properties from given +uuid+
	def delete_resource( uuid )
		self.transaction do			
			resources = @metadata[ :resources ]
			
			# Remove properties.
			@metadata[ :metaval ].
				filter( :r_id => resources.filter( :uuid => uuid.to_s ).select( :id ) ).delete
			
			# Remove resource row.
			resources.filter( :uuid => uuid.to_s ).delete
		end
	end


	### MetaStore API: Returns a list of all property keys in the database.
	def get_all_property_keys
		@metadata[ :metakey ].select( :key ).distinct.map( :key ).
			collect { |k| k.to_sym }
	end
	

	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		return @metadata[ :metaval, :metakey ].
			filter( :metaval__m_id => :metakey__id, :metakey__key => key ).
			distinct.select( :metaval__val ).
			map( :val ).compact
	end
	
	
	### MetaStore API: Return an array of uuids whose metadata +key+ is
	### exactly +value+.
	def find_by_exact_properties( hash )
		uuids = hash.reject {|k,v| v.nil? }.inject(nil) do |ary, pair|
			key, value = *pair
			key = key.to_s

			matching_uuids = @metadata[ :resources, :metakey, :metaval ].
				filter( :metakey__key  => key, 
						:metakey__id   => :metaval__m_id, 
						:metaval__val  => value, 
						:metaval__r_id => :resources__id ).map( :uuid )

			if ary
				ary &= matching_uuids
			else
				ary = matching_uuids
			end
			
			ary
		end
		
		return uuids ? uuids : []		
	end


	### MetaStore API: Return an array of uuids whose metadata +key+ is
	### a wildcard match of +value+.
	def find_by_matching_properties( hash )
		uuids = hash.reject {|k,v| v.nil? }.inject(nil) do |ary, pair|
			key, pattern = *pair
			key = key.to_s

			value = pattern.to_s.gsub( '*', '%' )
			matching_uuids = @metadata[ :resources, :metakey, :metaval ].
				filter { :metakey__key  == key			  &&
						 :metakey__id   == :metaval__m_id &&
						 :metaval__val  =~ value		  &&
						 :metaval__r_id == :resources__id }.map( :uuid )
			
			if ary
				ary &= matching_uuids
			else
				ary = matching_uuids
			end
			
			ary
		end
		
		return uuids ? uuids : []		
	end


	### Delete all resources from the database, but preserve the keys
	def clear
		self.transaction do
			@metadata[ :resources ].delete
			@metadata[ :metaval   ].delete
		end
	end



	#########
	protected
	#########

	### Create the metadata database if it doesn't already exist
	def init_db
		return if @metadata.table_exists?( :resources ) &&
				  @metadata.table_exists?( :metakey )   &&
				  @metadata.table_exists?( :metaval )

		self.log.info "Initializing a new sequel backed metastore"

		if @metadata.uri =~ /^sqlite:/i
			@metadata << 'PRAGMA default_cache_size=7000'
			@metadata << 'PRAGMA default_synchronous=OFF'
			@metadata << 'PRAGMA count_changes=OFF'
		end

		@metadata.create_table( :resources ) do
			primary_key	:id
			char :uuid, :size => 36, :unique => true
		end

		@metadata.create_table( :metakey ) do
			primary_key	:id
			varchar :key, :unique => true
		end

		@metadata.create_table( :metaval ) do
			integer :r_id, :index => true
			integer :m_id, :index => true
			text    :val,  :index => true

			primary_key :r_id, :m_id
		end
	end

	
	### Return the id of a given resource or metakey, or if none exist,
	### create a new row and return the id.
	def get_id( key, value )
		case key
		when :resources
			row = @metadata[ key ].filter( :uuid => value.to_s ).first
		when :metakey
			row = @metadata[ key ].filter( :key => value.to_s ).first
		else
			raise "Unknown ID type %p!" % [ key ]
		end

		# return a found ID.
		#
		return row[:id] unless row.nil?

		# create a new row for the requested object, and return the new ID.
		#
		self.log.debug "Creating new %s row: %s" % [ key, value ]
		return @metadata[ key ] << [ nil, value.to_s ]
	end
end
