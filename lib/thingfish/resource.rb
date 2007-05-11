#!/usr/bin/ruby
# 
# ThingFish::Resource -- a resource in a ThingFish store
# 
# == Synopsis
# 
#   require 'thingfish/resource'
#   require 'thingfish/client'
#
#   # Connect to the ThingFish server
#   client = ThingFish::Client.new( server, username, password )
#
#   # Create the entry
#   data = File.read( 'mahlonblob.dxf' )
#   resource = ThingFish::Resource.new( data )
#
#   # ...or use an IO object to avoid reading the whole file into memory
#   resource = ThingFish::Resource.new( File.open("mahlonblob.dxf") )
#   
#   # Set some metadata values
#   resource.format = 'image/x-dxf'
#   resource.creator = 'Johnson James'
#   resource.description = 'A model for a blob of concrete'
#
#   # Now save it to the store and print out its uuid
#   uuid = client.store( resource )
#   puts "Stored as #{uuid}"
#   
#   # Or create it with the client and save it directly:
#   resource = ThingFish::Resource.new( io, client )
#   resource.save
#   
#   # Create it with metadata
#   resource = ThingFish::Resource.new( io,
#     :creator => 'Izzy P. Switchback',
#     :description => 'VCard for Izzy P. Switchback' )
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

require 'thingfish'
require 'thingfish/mixins'


### Resource wrapper class
class ThingFish::Resource
	include ThingFish::Loggable
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################
	
	### Create a new ThingFish::Resource from the specified +datasource+, which can 
	### be either a String containing the data or an IO object from which the 
	### resource can be read.
	def initialize( datasource, metadata={} )
		@client = nil
		@data = nil
		@location = nil

		@io = normalize_io_obj( datasource )
		@metadata = metadata
	end


	######
	public
	######

	# Metadata hash
	attr_reader :metadata

	# The ThingFish::Client the resource is stored in (or will be stored in when it
	# is saved)
	attr_accessor :client

	# The IO object containing the resource data
	attr_accessor :io

	# The URI where this resource is stored (if it has been stored)
	attr_accessor :location
	

	### Read the data for the resource into a String and return it.
	def data
		@data ||= @io.read
	end
	
	
	#########
	protected
	#########

	### Proxy method for calling methods that correspond to keys.
	def method_missing( sym, val=nil, *args )
		case sym.to_s
		when /^(?:has_)(\w+)\?$/
			propname = $1.to_sym
			return @metadata.key?( propname )

		when /^(\w+)=$/
			propname = $1.to_sym
			return @metadata[ propname ] = val
			
		else
			return @metadata[ sym ]
		end
	end
	


	### Set the datasource for the object to +sourceobj+, which can be either an
	### IO object (in which case it's used directly), or the resource data in a 
	### String, in which case the datasource will be set to a StringIO containing
	### the data.
	def normalize_io_obj( sourceobj )
		return sourceobj if sourceobj.respond_to?( :read )
		@data = sourceobj
		return StringIO.new( sourceobj )
	end
	

end # ThingFish::Resource

# vim: set nosta noet ts=4 sw=4:
