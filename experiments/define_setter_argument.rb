#!/usr/bin/env ruby

# This is an experiment to see what is causing this test failure (in daemon_spec):
#
# uses default config IP when constructed with a differing ip config
# <TCPServer (class)> expected :new with ("127.0.0.1", 3474) but received it
#    with (["127.0.0.1"], 3474)

class Foo

	def initialize
		@hash = {}
	end
	
	def method_missing( sym, *args )
		key = sym.to_s.sub( /(=|\?)$/, '' ).to_sym

		self.class.class_eval {
			define_method( key ) {
				$stderr.puts "  fetching value for %p: %p" % [ key, @hash[key] ]
				if @hash[ key ].is_a?( Hash )
					@hash[ key ] = ConfigStruct.new( @hash[key] )
				end

				@hash[ key ]
			}
			define_method( "#{key}?" ) {
				$stderr.puts "  predicate value for %p: %p" % [ key, @hash[key] ? true : false ]
				@hash[key] ? true : false
			}
			define_method( "#{key}=" ) {|val|
				$stderr.puts "  setting value for %p to %p" % [ key, val ]
				@hash[key] = val
			}
		}

		self.method( sym ).call( *args )
	end
	
end


f = Foo.new

f.blah = 'a string'
f.blah
f.blah?

f.blah = 'a string'
f.blah
f.blah?

