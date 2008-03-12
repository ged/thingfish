#!/usr/bin/env ruby

require 'thingfish/client'

client = ThingFish::Client.new( 'thingfish.laika.com' )
resource = client.store( File.open("rss.png"), :format => 'image/png' )

resource.uuid # => "a52ec552-2c50-11dc-8e32-abc548881c84"

