require 'thingfish/client'

# Create a new client which will connect to thingfish.laika.com on the 
# default port.
client = ThingFish::Client.new( 'thingfish.laika.com' )

# -or-

client = ThingFish::Client.new( 'https://thingfish.laika.com:3474/' )

# -or-

# Create a client and configure it via attributes
client = ThingFish::Client.new
client.host = 'thingfish.laika.com'
client.port = 5000
client.user = 'mgranger'
client.password = 'myS00perSekrit'

client  # => 

