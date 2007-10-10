require 'thingfish/client'

client = ThingFish::Client.new( 'thingfish.laika.com' )
resource = client.fetch( 'a3f4e060-dffa-11db-a8e7-4bd9759f4985' )

resource.uuid								# => 
resource.format								# => 
resource.data[0..20]						# => 

