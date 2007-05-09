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


	### Create a new ThingFish::Resource from the specified +datasource+. If the 
	### optional +client+ argument is given (a ThingFish::Client object or similar), 
	### use it to save the resource.
	def initialize( datasource, client=nil, metadata={} )
	end
	

end # ThingFish::Resource

# vim: set nosta noet ts=4 sw=4:
