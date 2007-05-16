#!/usr/bin/env ruby

require 'thingfish/client'

client = ThingFish::Client.new( 'thingfish.laika.com' )
resource = client.store( File.open("rss.png"), :format => 'image/png' )

resource.uuid												# => 

# ~> -:3:in `require': no such file to load -- thingfish/client (LoadError)
# ~> 	from -:3
