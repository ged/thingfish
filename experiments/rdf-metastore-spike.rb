#!/usr/bin/ruby
# 
# Spike to work out how the RDF metastore will work
#
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )

	require basedir + 'utils.rb'
	include UtilityFunctions
}


require 'rubygems'
require 'rdf/redland'
require 'rdf/redland/constants'
require 'uuidtools'
require 'thingfish'

module ThingFish
	module Schemas
		URL = 'http://opensource.laika.com/rdf/2007/02/thingfish-schema#'
		TFNS = Redland::Namespace.new( URL )

		TF_PERMISSIONS = TFNS['permissions']
	end
	
	class PropSet
		def initialize( resource )
			@resource = resource
		end
		
		attr_reader :resource
		
		def method_missing( sym, *args )
			return super unless sym.to_s =~ /(\w+)(=|\?)?/
			
			propname = $1
			url = Schemas::TFNS[ propname ]
			op = $2

			case op
			when '='
				@resource.add_property( url, args.first )
				
			when '?'
				@resource.get_property( url ) ? true : false
				
			else
				@resource.get_property( url )
			end
		end
	end
	
	class Metastore
		def initialize
			# @store = Redland::HashStore.new( 'memory', 'thingfish' )
			@store = Redland::TripleStore.new( 'postgresql', 'test',
			 	"host='localhost',database='test',user='ged'" )
			@model = Redland::Model.new( @store )
		end
		
		attr_reader :model
		
		def []( uuid )
			res = Redland::Resource.new( "http://thingfish/#{uuid}", @model )
			return PropSet.new( res )
		end
		
		def find( pred, object )
			return @model.find( nil, pred, object ).collect do |st|
				PropSet.new( st.subject )
			end
		end
	end
end

USERS = %w[mahlon michael bob luna]
store = ThingFish::Metastore.new

30.times do |i|
	uuid = UUIDTools::UUID.timestamp_create
	metadata = store[ uuid.to_s ]
	metadata.permissions = rand(1_000_000).to_s
	metadata.mimetype = 'text/plain'
	metadata.owner = USERS.sort_by {rand}.first
	metadata.serial = 'i'
	
	puts "Created a chunk '%s' owned by '%s'" % [uuid, metadata.owner]
end

ownerprop = ThingFish::Schemas::TFNS['owner']

USERS.each do |user|
	puts "User '%s':" % [user]
	puts "  " + store.find( ownerprop, user ).collect {|ps| ps.resource.to_s }.join("\n  ")
end

query_string = %Q{
	PREFIX tf: <http://opensource.laika.com/rdf/2007/02/thingfish-schema#>
	PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
	
	SELECT ?uuid
	WHERE
	{ 
            ?uuid tf:owner ?o;
                  tf:permissions ?perm .
			
            FILTER regex(?o, "^m", "i") .
	    FILTER (xsd:integer(?perm) >= 500000) .
	}
}

puts
q = Redland::Query.new( query_string, 'sparql' )
res = store.model.query_execute( q )
puts "Query results!"
until res.finished?
	puts res.binding_value_by_name( 'uuid' )
	res.next
end

