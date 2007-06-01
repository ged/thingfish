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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

require 'pathname'
require 'sqlite3'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/metastore'


### Add pragmas to SQLite3 (because schema_cookie and user_cookie have been 
### renamed)
module SQLite3::Pragmas
	def schema_version
		get_int_pragma "schema_version"
	end

	def schema_version=( version )
		set_int_pragma "schema_version", version
	end

	def user_version
		get_int_pragma "user_version"
	end

	def user_version=( version )
		set_int_pragma "user_version", version
	end
end


### A metastore backend that stores metadata tuples in a SQLite3 database
class ThingFish::SQLite3MetaStore < ThingFish::MetaStore

	include ThingFish::Loggable,
	        ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default root directory
	DEFAULT_ROOT = '/tmp/thingstore'

	# The name of the schema file under resources/
	SCHEMA_RESOURCE_NAME = 'base-schema.sql'


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new SQLite3MetaStore
	def initialize( options={} )

		super
		@root = Pathname.new( options[:root] || DEFAULT_ROOT )
		@root.mkpath
		@dbname = @root + 'metadata.db'
		@schema = nil

		@metadata = SQLite3::Database.new( @dbname )
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
	

	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		set_sql = %q{
			REPLACE INTO metaval
				VALUES (
					:id,
					( SELECT id FROM metakey WHERE key= :propname ),
					:value
				)
		}

		@metadata.transaction
		begin
			r_id = get_resource_id( uuid )
			@metadata.execute( set_sql, r_id, propname, value )
		rescue SQLite3::SQLException
			self.log.debug "Creating new metadata property row: #{propname}"

			propadd_sql = %q{
				INSERT INTO metakey
					VALUES ( NULL, :propname )
			}

			@metadata.execute( propadd_sql, propname )
			@metadata.execute( set_sql, r_id, propname, value )
		end
		@metadata.commit
	end
	
	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		get_sql = %q{
			SELECT v.val
			FROM metaval AS v, metakey as m, resources AS r
			WHERE
				m.id = v.m_id AND
				r.id = v.r_id AND
				v.r_id = :id  AND
				m.key = :propname
		}

		results = nil
		@metadata.transaction do
			r_id = get_resource_id( uuid )
			results = @metadata.get_first_value( get_sql, r_id, propname )
		end
		return results
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		get_sql = %q{
			SELECT m.key, v.val
			FROM metaval AS v, metakey as m, resources AS r
			WHERE
				m.id = v.m_id AND
				r.id = v.r_id AND
				v.r_id = :id
		}

		results = {}
		@metadata.transaction do
			r_id = get_resource_id( uuid )
			@metadata.execute( get_sql, r_id ) do | propname, propval |
				results[ propname.to_sym ] = propval
			end
		end
		return results
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		results = get_property( uuid, propname )
		return ! results.nil?
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		delete_sql = %q{
			DELETE FROM metaval
			WHERE
				r_id = ( SELECT id FROM resources WHERE uuid = :uuid )
				AND
				m_id = ( SELECT id FROM metakey WHERE key = :propname )
		}

		begin
			@metadata.execute( delete_sql, uuid, propname )
		rescue SQLite3::SQLException
			# no-op - not being able to find the uuid or propname in SQL
			# in this case is not a problem.
		end
	end
	
	
	### MetaStore API: Removes all properties from given +uuid+
	def delete_properties( uuid )
		delete_sql = %q{
			DELETE FROM resources
			WHERE uuid = :uuid
		}
		# trigger cleans up the other tables
		@metadata.execute( delete_sql, uuid )
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
		@metadata.transaction( :exclusive ) do
			@metadata.execute( "delete from resources" )
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
	

	### Return the id of a given resource uuid, or if none exist,
	### create a new row and return the id.
	def get_resource_id( uuid )
		r_id = @metadata.get_first_value(
			'SELECT id FROM resources WHERE uuid = :uuid',
			uuid
		)
		return r_id.to_i unless r_id.nil?

		# create a new row for this resource
		self.log.debug "Creating new metadata row: #{uuid}"
		@metadata.execute(
			'INSERT into resources VALUES ( NULL, :uuid )',
			uuid
		)
		return @metadata.last_insert_row_id
	end

end

