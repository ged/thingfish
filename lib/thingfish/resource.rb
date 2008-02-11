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
#   # Create it with metadata   #TODO#
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
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/mixins'

require 'tempfile'


### Resource wrapper class
class ThingFish::Resource
	include ThingFish::Loggable,
	        ThingFish::Constants,
	        ThingFish::Constants::Patterns
	
	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The maximum number of bytes before the resource instance's data is
	# written out to a tempfile
	MAX_INMEMORY_BODY = 128.kilobytes
	


	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### Create a new ThingFish::Resource object from the data in the specified
	### +filename+. Any +metadata+ given will be also set in the resulting object.
	def self::from_file( filename, metadata={} )
		return new( File.open(filename, 'r'), metadata )
	end
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################
	
	### Create a new ThingFish::Resource, optionally from the data in the given +datasource+, which 
	### can be a String containing the data, or any object that responds to #read (e.g., an IO). 
	### If the optional +client+ argument is set, it will be used as the ThingFish::Client instance 
	### which should be used to load and store the resource on the server. If the +uuid+ argument
	### is given, it will be used as the resource's Universally Unique IDentifier when 
	### communicating with the server. The +metadata+ Hash may include one or more metadata 
	### key-value pairs which will be set on the resource.
	def initialize( datasource=nil, client=nil, uuid=nil, metadata={} )
		metadata ||= {}

		metadata, datasource = datasource, nil if datasource.is_a?( Hash )
		metadata, client = client, nil if client.is_a?( Hash )
		metadata, uuid = uuid, nil if uuid.is_a?( Hash )

		@io     = normalize_io_obj( datasource )
		@client = client
		@uuid   = uuid

		# Use the accessor to set all remaining pairs
        @metadata = {}
		metadata.each do |key, val|
			self.send( "#{key}=", val )
		end
	end


	######
	public
	######

	# Metadata hash
	attr_reader :metadata

	# The ThingFish::Client the resource is stored in (or will be stored in when it
	# is saved)
	attr_accessor :client

	# The object containing the resource data
	attr_accessor :io

	# The resource's UUID (if it has one)
	attr_accessor :uuid


	### Read the data for the resource into a String and return it.
	def data
		rval = nil

		if @io
			rval = @io.read
			@io.rewind
		end
		
		return rval
	end
	
	
	### Write the data from the resource to the given +io+ object.
	def export( io )
		
		buf = ''
		while @io.read( 8192, buf )
			until buf.empty?
				bytes = io.write( buf )
				buf.slice!( 0, bytes )
			end
		end
		
		@io.rewind
	end
	
	
	### Save the resource to the server using the resource's client. If no client is
	### set for this resource, this method raises a RuntimeError.
	def save
		raise ThingFish::ResourceError, "no client set" unless @client
		@client.store( self )
	end
	
	
	### Override Kernel#format to return the 'format' metadata key instead.
	def format
		return @metadata[ :format ]
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
		return nil if sourceobj.nil? || (sourceobj.is_a?(String) && sourceobj.empty?)
		return sourceobj if sourceobj.respond_to?( :read )
		return StringIO.new( sourceobj )
	end
	

end # ThingFish::Resource

# vim: set nosta noet ts=4 sw=4:
