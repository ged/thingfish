require 'thingfish/client'

uuid = 'a3f4e060-dffa-11db-a8e7-4bd9759f4985'
client = ThingFish::Client.new( 'thingfish.laika.com' )
resource = client.fetch( uuid )							# => 

