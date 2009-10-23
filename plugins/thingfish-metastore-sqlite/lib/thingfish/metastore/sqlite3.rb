#!/usr/bin/ruby
#
# ThingFish::SQLite3MetaStore-- a metastore plugin for ThingFish.
#
# == Synopsis
#
#   require 'thingfish/metastore'
#
#   ms = ThingFish::MetaStore.create( "sqlite3" )
#
#   ms.set_property( uuid, 'hands', 'buttery' )
#   ms.get_property( uuid, 'pliz_count' )			# => 2
#   ms.get_properties( uuid )						# => {...}
#
#   metadata = ms[ uuid ]
#   metadata.format = 'application/x-yaml'
#   metadata.format		# => 'application/x-yaml'
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
require 'sqlite3'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/metastore/simple'


### Add pragmas to SQLite3 (because schema_cookie and user_cookie have been
### renamed)
module SQLite3::Pragmas

	### Get the schema version from the database (the value of the 'schema_version'
	### pragma value)
	def schema_version
		get_int_pragma "schema_version"
	end

	### Set the schema version from the database (the value of the 'schema_version'
	### pragma value)
	def schema_version=( version )
		set_int_pragma "schema_version", version
	end

	### Get the user version from the database (the value of the 'user_version'
	### pragma value)
	def user_version
		get_int_pragma "user_version"
	end

	### Set the user version from the database (the value of the 'user_version'
	### pragma value)
	def user_version=( version )
		set_int_pragma "user_version", version
	end
end


### A metastore backend that stores metadata tuples in a SQLite3 database
class ThingFish::SQLite3MetaStore < ThingFish::SimpleMetaStore

	extend Forwardable

	include ThingFish::Loggable,
	        ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The name of the schema file under resources/
	SCHEMA_RESOURCE_NAME = 'base-schema.sql'


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new SQLite3MetaStore
	def initialize( datadir, spooldir, options={} )
		raise ArgumentError, "invalid data directory %p" % [ datadir ] unless
			datadir.is_a?( Pathname )

		super

		self.datadir.mkpath
		@dbname = self.datadir + 'metastore.db'
		@schema = nil
		@resource_dir = options['resource_dir'] || options[:resource_dir]

		@metadata = SQLite3::Database.new( @dbname.to_s )
		self.init_db

		# TODO:
		# automatic schema updates
	end


	######
	public
	######

	# The sqlite3 database handle associated with the store
	attr_accessor :metadata

	# The name of the sqlite3 database that is backing the metastore
	attr_reader :dbname

	# Provide direct transactional control for ease of testing.
	def_delegators :@metadata, :rollback, :commit, :transaction_active?


	### These transaction fallthrough methods are discouraged for regular use,
	### in favor of the #transaction metastore API.
	def begin_transaction #:nodoc:
		@metadata.transaction
	end


	### Returns +true+ if the metadata database needs to be created.
	def db_needs_init?
		return @metadata.user_version.zero?
	end


	### Returns +true+ if the metadata database's schema is a lower rev
	### than the schema the receiver knows about.
	def db_needs_update?
		rev = self.schema_rev or return false
		installed_rev = self.installed_schema_rev

		return rev > installed_rev ? true : false
	end




	### Return the schema that describes the database as a String, loading
	### it from the plugin resources if necessary
	def schema
		unless @schema
			@schema = self.get_resource( SCHEMA_RESOURCE_NAME )
			self.log.debug "Schema loaded as: %p" % [@schema]
			@schema.gsub!( /\$Rev(?:: (\d+))?\s*\$/ ) do |match|
				$1 ? $1 : '0'
			end
			self.log.debug "After transformation of  the rev: %p" % [@schema]
		end

		return @schema
	end


	### Extract the revision number from the schema resource and return it.
	def schema_rev
		if self.schema.match( /user_version\s*=\s*(\d+)/i )
			return Integer( $1 )
		else
			return nil
		end
	end


	### Returns the revision number of the schema that was installed for the
	### current db.
	def installed_schema_rev
		return @metadata.user_version
	end


	### Delete all resources from the database, but preserve the keys
	def clear
		@metadata.execute( 'DELETE FROM resources' )
	end


	### Execute a block in the scope of a transaction, committing it when the block returns.
	### If an exception is raised in the block, the transaction is aborted.
	def transaction( &block )
		if @metadata.transaction_active?
			block.call
		else
			@metadata.transaction( &block )
		end
	end


	###
	### Simple MetaStore API
	###

	### MetaStore API: Set the property associated with +uuid+ specified by
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		r_id = get_id( :resource, uuid )
		m_id = get_id( :metakey, propname )
		@metadata.execute(%q{
			REPLACE INTO metaval
				VALUES ( :r_id, :m_id, :value ) },
			r_id, m_id, value
		)
	end


	### MetaStore API: Set the properties associated with the given +uuid+ to those
	### in the provided +propshash+.
	def set_properties( uuid, propshash )
		self.transaction do
			self.delete_resource( uuid )
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


	SQL_GET_PROPERTY = %q{
		SELECT v.val
		FROM metaval AS v, metakey as m, resources AS r
		WHERE
			m.id = v.m_id AND
			r.id = v.r_id AND
			v.r_id = :id  AND
			m.key = :propname
	}

	### MetaStore API: Return the property associated with +uuid+ specified by
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		r_id = get_id( :resource, uuid )
		return @metadata.get_first_value( SQL_GET_PROPERTY, r_id, propname )
	end


	SQL_GET_PROPERTIES = %q{
		SELECT m.key, v.val
		FROM metaval AS v, metakey as m, resources AS r
		WHERE
			m.id = v.m_id AND
			r.id = v.r_id AND
			v.r_id = :id
	}

	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		r_id = get_id( :resource, uuid )
		return @metadata.execute( SQL_GET_PROPERTIES, r_id ).inject({}) do |hash, row|
			hash[ row.first.to_sym ] = row.last
			hash
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ exists in the metastore.
	def has_uuid?( uuid )
		return @metadata.get_first_value( 'SELECT id FROM resources WHERE uuid = :uuid', uuid ) ?
			true :
			false
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		return get_property( uuid, propname ) != nil
	end


	SQL_DELETE_PROPERTY = %q{
		DELETE FROM metaval
		WHERE
			r_id = ( SELECT id FROM resources WHERE uuid = :uuid )
			AND
			m_id = ( SELECT id FROM metakey WHERE key = :propname )
	}

	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		@metadata.execute( SQL_DELETE_PROPERTY, uuid, propname )
	rescue SQLite3::SQLException
		# no-op - not being able to find the uuid or propname in SQL
		# in this case is not a problem.
	end


	SQL_DELETE_PROPERTIES = %Q{
		DELETE FROM metaval
		WHERE
			r_id = ( SELECT id FROM resources WHERE uuid = :uuid )
			AND
			m_id IN( SELECT id FROM metakey WHERE key IN( %s ) )
	}

	### MetaStore API: Removes the properties specified by +propnames+ from those
	### associated with +uuid+.
	def delete_properties( uuid, *propnames )
		placeholders = ['?'] * propnames.length
		delete_sql = SQL_DELETE_PROPERTIES % [ placeholders.join(',') ]
		@metadata.execute( delete_sql, uuid, *propnames )
	rescue SQLite3::SQLException
		# no-op - not being able to find the uuid or propname in SQL
		# in this case is not a problem.
	end


	### MetaStore API: Removes all properties from given +uuid+
	def delete_resource( uuid )
		# trigger cleans up the other tables
		@metadata.execute( 'DELETE FROM resources WHERE uuid = :uuid', uuid )
	end


	### MetaStore API: Returns a list of all property keys in the database.
	def get_all_property_keys
		return @metadata.execute( 'SELECT DISTINCT key FROM metakey' ).
			flatten.collect {|k| k.to_sym }
	end


	SQL_GET_ALL_PROPERTY_VALUES = %q{
		SELECT DISTINCT v.val FROM metaval AS v, metakey AS k
		WHERE
			v.m_id = k.id AND
			k.key  = :key
	}

	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		return @metadata.execute( SQL_GET_ALL_PROPERTY_VALUES, key ).flatten.compact
	end

	SQL_SELECT_UUIDS = %q{
		SELECT r.uuid, k.key, v.val
		FROM resources AS r,
		     metakey AS k,
		     metaval AS v
		WHERE
			r.id IN ( %s ) AND
			r.id = v.r_id AND
			k.id = v.m_id
	}

	SQL_SELECT_EXACT = %q{
		SELECT r.id
		FROM resources AS r, metakey AS k, metaval AS v
		WHERE
			k.key  = :key AND
			k.id   = v.m_id AND
			lower(v.val) = :value AND
			v.r_id = r.id
	}

	### MetaStore API: Return an array of uuids whose metadata matched the criteria
	### specified by +key+ and +value+. This is an exact match search.
	def find_exact_uuids( key, value )
		ids = @metadata.execute( SQL_SELECT_EXACT, key.to_s, value.downcase )
		query = SQL_SELECT_UUIDS % [ ids.join(',') ]
		return @metadata.execute( query ).inject({}) do |tuples,row|
			tuples[ row[0] ] ||= {}
			tuples[ row[0] ][ row[1].to_sym ] = row[2]
			tuples
		end
	end


	SQL_SELECT_MATCHING = %q{
		SELECT r.id
		FROM resources AS r, metakey AS k, metaval AS v
		WHERE
			k.key  = :key AND
			k.id   = v.m_id AND
			v.val  like :value AND
			v.r_id = r.id
	}

	### MetaStore API:  Return an array of uuids whose metadata matched the criteria
	### specified by +key+ and +value+. This is a wildcard search.
	def find_matching_uuids( key, value )
		value = value.to_s.gsub( '*', '%' )
		ids = @metadata.execute( SQL_SELECT_MATCHING, key.to_s, value )

		query = SQL_SELECT_UUIDS % [ ids.join(',') ]
		return @metadata.execute( query ).inject({}) do |tuples,row|
			tuples[ row[0] ] ||= {}
			tuples[ row[0] ][ row[1].to_sym ] = row[2]
			tuples
		end
	end


	SQL_DUMP_STORE = %q{
		SELECT uuid, key, val
		FROM metaval
		INNER JOIN metakey ON (metakey.id = metaval.m_id)
		INNER JOIN resources ON (resources.id = metaval.r_id)
	}

	### MetaStore API: Return a hash of all the values in the store, keyed by UUID.
	def dump_store
		dumpstruct = Hash.new {|h,k| h[k] = {} }

		@metadata.execute( SQL_DUMP_STORE ).each do |uuid, key, val|
			dumpstruct[ uuid ][ key.to_sym ] = val
		end

		return dumpstruct
	end


	### Metastore API: Replace all values in the store with those in the given hash.
	def load_store( hash )
		self.clear

		hash.each do |uuid, properties|
			r_id = get_id( :resource, uuid )

			properties.each do |propname, value|
				m_id = get_id( :metakey, propname )
				@metadata.execute(%q{
					REPLACE INTO metaval
						VALUES ( :r_id, :m_id, :value ) },
					r_id, m_id, value
				)

			end
		end
	end


	SQL_EACH_RESOURCE = %q{
		SELECT key, val
		FROM metaval
			JOIN metakey ON (metakey.id = metaval.m_id)
		WHERE (r_id = :id)
	}

	### Metastore API: Yield all the metadata in the store one resource at a time
	def each_resource # :yields: uuid, properties_hash
		@metadata.execute( 'SELECT id, uuid FROM resources' ).each do |id, uuid|
			self.log.debug "Gathering properties for %s" % [ uuid ]

			properties = @metadata.execute( SQL_EACH_RESOURCE, id ).inject({}) do |props,pair|
				self.log.debug "  adding property %p" % [ pair ]
				props[ pair[0].to_sym ] = pair[1]
				props
			end

			self.log.debug "Yielding %s: %p" % [ uuid, properties ]
			yield( uuid, properties )
		end
	end


	#########
	protected
	#########

	### Create the metadata database if it doesn't already exist
	def init_db
		return unless self.db_needs_init?
		self.log.info "Initializing a new sqlite3 backed metastore"

		# Load the schema and fix up the schema version
		sql = self.schema or raise "No schema?!?"
		self.log.debug "Creating database: %p" % [sql]

		# Upload the schema
		@metadata.execute_batch( sql )
	end


	### Return the id of a given resource or metakey, or if none exist,
	### create a new row and return the id.
	def get_id( key, value )
		case key
		when :resource
			select_sql = 'SELECT id FROM resources WHERE uuid = :uuid'
			insert_sql = 'INSERT into resources VALUES ( NULL, :uuid )'
		when :metakey
			select_sql = 'SELECT id FROM metakey WHERE key = :propname'
			insert_sql = 'INSERT INTO metakey VALUES ( NULL, :propname )'
		else
			raise "Unknown ID type %p!" % [ key ]
		end

		# return a found ID.
		#
		id = @metadata.get_first_value( select_sql, value )
		return id.to_i unless id.nil?

		# create a new row for the requested object, and return the new ID.
		#
		self.log.debug "Creating new %s row: %s" % [ key, value ]
		@metadata.execute( insert_sql, value )
		return @metadata.last_insert_row_id
	end
end

