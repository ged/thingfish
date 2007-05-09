#!/usr/bin/env ruby

require 'thingfish/client'
require 'thingfish/resource'

# Create a new client
client = ThingFish::Client.new 'thingfish.laika.com',
	:user => 'mgranger',
	:password => 'myS00perSekrit'    				# => 

# Upload a new resource
resource = ThingFish::Resource.from_file( "rss.png" )
resource.format 									# =>
client.store( resource )

# Download a resource
resource = client.fetch( "bd3f8ad6-de54-11db-b3c6-d7f7e9f1ac25" )
resource.inspect										# => 
resource.format										# => 
resource.filename										# => 
resource.write_to_file

# Search for resources
entries = client.find( :format => 'image/jpeg', :owner => 'mgranger' )
entries.each do |e| e.write_to_file end

