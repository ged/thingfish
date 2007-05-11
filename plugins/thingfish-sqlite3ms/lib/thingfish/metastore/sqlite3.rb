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


class ThingFish::SQLite3MetaStore < ThingFish::MetaStore

	include ThingFish::Loggable,
	        ThingFish::ResourceLoader

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default root directory
	DEFAULT_ROOT = '/tmp/thingstore'



	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new SQLite3MetaStore
	def initialize( options={} )

		super
		@root = Pathname.new( options[:root] || DEFAULT_ROOT )
		@root.mkpath
		@dbname = @root + 'metadata.db'

		db_needs_init = ! File.exists?( @dbname )
		@metadata = SQLite3::Database.new( @dbname )

		if db_needs_init
			schema = self.get_resource( 'base-schema.sql' )
			self.log.info "Initializing a new sqlite3 backed metastore"
			@metadata.execute_batch( schema )
			@metadata.execute( 'INSERT INTO version VALUES ( :rev )',
				SVNRev.scan(/(\d+)/).flatten.first || 0 )
		end

		# TODO:
		# automatic schema updates
	end


	######
	public
	######

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

	#########
	protected
	#########

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

