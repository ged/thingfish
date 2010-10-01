#!/usr/bin/env ruby
#
# Trying to figure out what the client API should do
# 
# Time-stamp: 2007-03-10
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )

	require basedir + "utils.rb"
	include UtilityFunctions
}

require 'thingfish/client'


### Create a new client
client = ThingFish::Client.new \
	'thingfish.laika.com',
	:username => 'mgranger',
	:password => 'myS00perSekrit/pa$$'

# -or-

client = ThingFish::Client.new
client.server = 'thingfish.laika.com'
client.username = 'mgranger'
client.password = 'myS00perSekrit/pa$$'


### Upload a new resource
entry = ThingFish::Resource.new( data )
entry = ThingFish::Resource.new( io_object )
entry.format = 'image/jpeg'

client.store( entry )

# -or-

entry = client.store( data )

# -or-

entry = client.store( io_object )


### Download a resource
entry = client.fetch( uuid )


### Search for resources
entries = client.find( :format => 'image/jpeg', :owner => 'mailto:ged@FaerieMUD.org' )

