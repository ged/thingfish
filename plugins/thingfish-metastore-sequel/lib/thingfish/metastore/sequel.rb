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
#  * Michael Granger <ged@FaerieMUD.org>
#  * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

gem 'sequel', '>= 2.2.0'

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


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new SequelMetaStore
	def initialize( datadir, spooldir, options={} )
		super

		@id_cache = { :resources => {}, :metakey => {} }

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
					Sequel.connect( options[:sequel_connect], :max_connections => 1 )

		# Enable query logging in debug mode
		self.log.debug {
			@metadata.logger = self.log_debug
			'Enabled SQL query logging'
		}

		self.init_db
	end


	######
	public
	######

	# The Sequel object that is backing the metastore
	attr_reader :metadata

	# Delegate transactions to the underlying Sequel object.
	def_delegators :@metadata, :transaction


	### Delete all resources from the database, but preserve the keys
	def clear
		self.transaction do
			@id_cache[ :resources ] = {}
			@metadata[ :resources ].delete
			@metadata[ :metaval   ].delete
		end
	end



	###
	### Simple Metastore API
	###

	### MetaStore API: Set the property associated with +uuid+ specified by
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		r_id = get_id( :resources, uuid.to_s )
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
		r_id = get_id( :resources, uuid.to_s )
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
		props = propnames.collect {|prop| prop.to_s }

		mv.filter( :r_id => r.filter( :uuid => uuid.to_s ).select( :id ),
		           :m_id => mk.filter( :key => props ).select( :id ) ).delete
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
			@id_cache[ :resources ].delete( uuid.to_s )
		end
	end


	### MetaStore API: Returns a list of all property keys in the database.
	def get_all_property_keys
		@metadata[ :metakey ].select( :key ).distinct.map( :key ).
			collect {|k| k.to_sym }
	end


	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		dataset = @metadata[ :metaval, :metakey ].
			filter( :metaval__m_id => :metakey__id, :metakey__key => key ).
			distinct

		return dataset.select( :metaval__val => :val ).map( :val ).compact
	end


	### MetaStore API: Return an array of uuids whose metadata matched the criteria
	### specified by +key+ and +value+. This is an exact match search.
	def find_exact_uuids( key, value )
		ids = @metadata[ :resources, :metakey, :metaval ].
			filter( :metakey__key  => key.to_s,
					:metakey__id   => :metaval__m_id,
					:lower.sql_function( :metaval__val ) => value.downcase,
					:metaval__r_id => :resources__id ).map( :r_id )

		return @metadata[ :resources, :metakey, :metaval ].
			filter( {:metakey__id   => :metaval__m_id,
				     :metaval__r_id => :resources__id,
					 :resources__id => ids} ).inject({}) do |tuples,row|
				tuples[ row[:uuid] ] ||= {}
				tuples[ row[:uuid] ][ row[:key].to_sym ] = row[:val]
				tuples
			end
	end


	### MetaStore API:  Return an array of uuids whose metadata matched the criteria
	### specified by +key+ and +value+. This is a wildcard search.
	def find_matching_uuids( key, value )
		value = value.to_s.gsub( '*', '%' )
		ids = @metadata[ :resources, :metakey, :metaval ].
			filter( (:metaval__val.like(value, :case_insensitive => true)) &
			        {:metakey__key  => key.to_s,
			         :metakey__id   => :metaval__m_id,
			         :metaval__r_id => :resources__id} ).map( :r_id )

		return @metadata[ :resources, :metakey, :metaval ].
			filter( {:metakey__id   => :metaval__m_id,
			         :metaval__r_id => :resources__id,
					 :resources__id => ids} ).inject({}) do |tuples,row|
				tuples[ row[:uuid] ] ||= {}
				tuples[ row[:uuid] ][ row[:key].to_sym ] = row[:val]
				tuples
			end
	end


	### MetaStore API: Dump the entire contents of the store as a Hash keyed by UUID.
	def dump_store
		dumpstruct = Hash.new {|h,k| h[k] = {} }

		dataset = @metadata[:metaval].
			join( :metakey, :id => :m_id ).
			join( :resources, :id => :metaval__r_id )

		dataset.select( :uuid, :key, :val ).each do |row|
			dumpstruct[ row[:uuid] ][ row[:key].to_sym ] = row[:val]
		end

		return dumpstruct
	end


	### Metastore API: Replace all values in the store with those in the given hash.
	def load_store( hash )
		self.transaction do
			self.clear

			hash.each do |uuid, properties|
				r_id = get_id( :resources, uuid )

				properties.each do |propname, value|
					m_id = get_id( :metakey, propname )
					@metadata[ :metaval ] << [ r_id, m_id, value.to_s ]
				end
			end

		end
	end


	### Metastore API: Yield all the metadata in the store one resource at a time
	def each_resource # :yields: uuid, properties_hash
		@metadata[ :resources ].select( :uuid, :id ).each do |row|
			self.log.debug "Building properties for %s" % [ row[:uuid] ]

			ds = @metadata[:metaval].
				join( :metakey, :id => :m_id ).
				filter( :r_id => row[:id] )

			properties = ds.select( :key, :val ).inject({}) do |hash, pair|
				self.log.debug "  adding property: %p" % [ pair ]
				hash[ pair[:key].to_sym ] = pair[:val]
				hash
			end

			self.log.debug "Yielding %p for UUID %s" % [ properties, row[:uuid] ]
			yield( row[:uuid], properties )
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

			primary_key [ :r_id, :m_id ]
		end
	end


	### Return the id of a given resource or metakey, or if none exist,
	### create a new row and return the id.  +key+ must be :resources or :uuid.
	def get_id( key, value )

		# Return the previously cached ID
		return @id_cache[ key ][ value ] unless @id_cache[ key ][ value ].nil?

		# Try and find an ID.
		column = ( key == :resources ? :uuid : :key )
		row = @metadata[ key ].filter( column => value.to_s ).first

		# Cache and return a found ID.
		#
		unless row.nil?
			@id_cache[ key ][ value ] = row[ :id ]
			return row[ :id ]
		end

		# Create a new row for the requested object, and return the new ID.
		#
		return @metadata[ key ] << { column => value.to_s }
	end

end # class ThingFish::SequelMetaStore
