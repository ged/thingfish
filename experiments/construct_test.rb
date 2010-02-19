#!/usr/bin/env ruby

require 'pp'
require 'logger'
require 'uuidtools'
require 'redleaf'
require 'redleaf/constants'

include Redleaf::Constants::CommonNamespaces

### fetch( [:title, :creation_date], 10, 20 )

# CONSTRUCT { ?uuid ?p ?o }
# WHERE {
# 	?uuid a		thingfish:Asset ;
# 	      ?p 	?o .
# 	OPTIONAL { ?uuid dcterms:title ?title } .
# 	OPTIONAL { ?uuid dc:created ?creation_date } .
# }
# ORDER BY ?title, ?creation_date, ?uuid
# LIMIT 10
# OFFSET 20

Redleaf.logger.level = Logger::DEBUG

g = Redleaf::Graph.new
thingfish = Redleaf::Namespace( 'http://thingfish.org/rdf/2009/11/thingfish.owl#' )

uuid = UUIDTools::UUID.timestamp_create
uuid2 = UUIDTools::UUID.timestamp_create
uuid3 = UUIDTools::UUID.timestamp_create

# @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
# @prefix dc: <http://purl.org/dc/elements/1.1/> .
# @prefix dcterms: <http://purl.org/dc/terms/> .
# @prefix thingfish: <http://thingfish.org/rdf/2009/11/thingfish.owl#> .
# 
# <urn:uuid:90020ab6-1bdd-11df-a8a9-0017f2c66c2c>
#     dc:author [
#         a <http://xmlns.com/foaf/0.1/Person> ;
#         <http://xmlns.com/foaf/0.1/family_name> "Granger" ;
#         <http://xmlns.com/foaf/0.1/givenname> "Michael" ;
#         <http://xmlns.com/foaf/0.1/homepage> <http://deveiate.org/> ;
#         <http://xmlns.com/foaf/0.1/mbox_sha1sum> "8680b054d586d747a6fcb7046e9ce7cb39554404" ;
#         <http://xmlns.com/foaf/0.1/name> "Michael Granger"
#     ] ;
#     dc:extent 1618 ;
#     dcterms:title "The Ether Bunny" ;
#     thingfish:namespace "test" ;
#     a thingfish:Asset .
# 
# <urn:uuid:90063ac8-1bdd-11df-a8a9-0017f2c66c2c>
#     dc:author [
#         a <http://xmlns.com/foaf/0.1/Person> ;
#         <http://xmlns.com/foaf/0.1/family_name> "Chamberlain" ;
#         <http://xmlns.com/foaf/0.1/givenname> "Skylr" ;
#         <http://xmlns.com/foaf/0.1/homepage> <http://skylr.org/> ;
#         <http://xmlns.com/foaf/0.1/mbox_sha1sum> "a55a445544b45c54d" ;
#         <http://xmlns.com/foaf/0.1/name> "Skylr Chamberlain"
#     ] ;
#     dc:extent 887277 ;
#     dcterms:title "Everyone Has Secrets" ;
#     thingfish:namespace "something" ;
#     a thingfish:Asset .
# 
# <urn:uuid:90063f64-1bdd-11df-a8a9-0017f2c66c2c>
#     dc:extent 1662 ;
#     dcterms:title "Your Son Is Gay" ;
#     a thingfish:Asset .

# g << {
# 	URI("urn:uuid:#{uuid}") 	=> {
# 		RDF[:type]				=> thingfish[:Asset],
# 		DC_TERMS[:title]		=> "The Ether Bunny",
# 		DC[:extent]				=> 1618,
# 		thingfish[:namespace]	=> 'test',
# 		DC[:author]             => {
# 			RDF[:type] => FOAF[:Person],
# 			FOAF[:name] => 'Michael Granger',
# 			FOAF[:givenname] => 'Michael',
# 			FOAF[:family_name] => 'Granger',
# 			FOAF[:mbox_sha1sum] => '8680b054d586d747a6fcb7046e9ce7cb39554404',
# 			FOAF[:homepage] => URI("http://deveiate.org/"),
# 		}
# 	},
# 	URI("urn:uuid:#{uuid2}") => {
# 		RDF[:type]              => thingfish[:Asset],
# 		DC_TERMS[:title]        => "Everyone Has Secrets",
# 		DC[:extent]             => 887277,
# 		thingfish[:namespace]   => 'something',
# 		DC[:author]             => {
# 			RDF[:type] => FOAF[:Person],
# 			FOAF[:name] => 'Skylr Chamberlain',
# 			FOAF[:givenname] => 'Skylr',
# 			FOAF[:family_name] => 'Chamberlain',
# 			FOAF[:mbox_sha1sum] => 'a55a445544b45c54d',
# 			FOAF[:homepage] => URI("http://skylr.org/"),
# 		}
# 	},
# 	URI("urn:uuid:#{uuid3}") => {
# 		RDF[:type]              => thingfish[:Asset],
# 		DC_TERMS[:title]        => "Your Son Is Gay",
# 		DC[:extent]             => 1662,
# 	}
# }

site = Redleaf::Namespace( 'http://example.org/stats#' )

g <<
	[:_a, FOAF[:name], "Alice" ] <<
	[:_a, site[:hits], 2349    ] <<
	[:_b, FOAF[:name], "Bob"   ] <<
	[:_b, site[:hits], 105     ] <<
	[:_c, FOAF[:name], "Eve"   ] <<
	[:_c, site[:hits], 181     ]


res = g.query(%{
	CONSTRUCT { [] foaf:name ?name }
	WHERE
	{ [] foaf:name ?name ;
	     site:hits ?hits .
	}
	ORDER BY desc(?hits)
	LIMIT 2
}, :site => site, :foaf => FOAF )

pp res.graph.statements

