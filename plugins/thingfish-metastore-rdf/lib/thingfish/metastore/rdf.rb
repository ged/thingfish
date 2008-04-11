#!/usr/bin/ruby
#
# ThingFish::RdfMetastore -- a metastore plugin for ThingFish that stores metadata in an
# RDF knowledgebase.
#
# == Synopsis
#
#   require 'thingfish/metastore'
#
#   ms = ThingFish::MetaStore.create( "rdf", 
#           :store => 'hashes', 
#           :hash_type => 'bdb', 
#           :dir => '/tmp/thingfish/metastore' )
#
#   ms.set_property( uuid, 'hands', 'buttery' )
#   ms.get_property( uuid, 'pliz_count' )			# => 2
#   ms.get_properties( uuid )						# => {...}
#
#   metadata = ms[ uuid ]
#   metadata.format = 'application/x-yaml'
#   metadata.format		# => 'application/x-yaml'
#   metadata.format?		# => true
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
# 
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

begin
	require 'pathname'
	require 'rdf/redland'
	require 'rdf/redland/constants'
	require 'rdf/redland/schemas/rdfs'
	require 'rdf/redland/dc'
	require 'uuidtools'
	require 'set'
	require 'uri'

	require 'thingfish'
	require 'thingfish/exceptions'
	require 'thingfish/metastore'
	require 'thingfish/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### ThingFish::RdfMetaStore -- a metastore plugin for ThingFish that stores metadata in
### a RDF knowledgebase.
class ThingFish::RdfMetaStore < ThingFish::MetaStore
	include ThingFish::Constants,
		ThingFish::Constants::Patterns

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default root directory
	DEFAULT_OPTIONS = {
		:store => 'hashes',
		:hash_type => 'memory',
		:name => 'thingfish',
	}

	# The SPARQL query template to use for searching
	QUERY_TEMPLATE = <<-END
		SELECT ?uuid
		WHERE
		{
			?uuid %s .
			%s
		}
	END

	
	### A few (hopefully) gentle additions for Redland::Uri
	module Redland::UriUtils
		include ThingFish::Constants::Patterns
		
		### Return the Redland::Uri object as a URI object.
		def to_ruby_uri
			URI.parse( self.to_s[ /^\[([^\[]+)\]$/, 1] )
		end
		
		
		### If the receiver is a UUID URN, return it after stripping the schema part
		### of the URI. Otherwise, returns nil.
		def to_uuid
			self.to_s[ UUID_URN, 1 ]
		end
		
		append_features Redland::Uri
	end
	

	# TODO: Change to parse vocabularies, thereby allowing user to add their
	# own via the config. Order of lookup would be:
	#   * User vocabularies
	#   * Standard vocabularies (DC, DCMI, etc.)
	#   * Fallback to ThingFish namespace

	### Map the given +key+ to a URI in one of the loaded vocabularies and return
	### it as a Redland::Node.
	def self::map_to_predicate( key )
		return Schemas::THINGFISH_NS[ key.to_s ]
	end
	
	
	### Unmap the given +predicate+ URI into a simple keyword.
	def self::unmap_from_predicate( predicate )
		uri = URI.parse( predicate.uri.to_s )
		return uri.fragment unless uri.fragment.nil?
		return uri.path[ %r{.*/(.*)}, 1 ]
	end
	

	# Predicate map that translates simple-string keys to their Dublin Core, 
	# DCMI Type Vocabulary, or RDF Schema equivalents.
	PredicateMap = {
		# Dublin Core
		:contributor           => 'http://purl.org/dc/elements/1.1/contributor',
		:coverage              => 'http://purl.org/dc/elements/1.1/coverage',
		:creator               => 'http://purl.org/dc/elements/1.1/creator',
		:date                  => 'http://purl.org/dc/elements/1.1/date',
		:description           => 'http://purl.org/dc/elements/1.1/description',
		:format                => 'http://purl.org/dc/elements/1.1/format',
		:identifier            => 'http://purl.org/dc/elements/1.1/identifier',
		:language              => 'http://purl.org/dc/elements/1.1/language',
		:publisher             => 'http://purl.org/dc/elements/1.1/publisher',
		:relation              => 'http://purl.org/dc/elements/1.1/relation',
		:rights                => 'http://purl.org/dc/elements/1.1/rights',
		:source                => 'http://purl.org/dc/elements/1.1/source',
		:subject               => 'http://purl.org/dc/elements/1.1/subject',
		:title                 => 'http://purl.org/dc/elements/1.1/title',
		:type                  => 'http://purl.org/dc/elements/1.1/type',
		
		# DCMI Elements
		:abstract              => 'http://purl.org/dc/terms/abstract',
		:accessRights          => 'http://purl.org/dc/terms/accessRights',
		:accrualMethod         => 'http://purl.org/dc/terms/accrualMethod',
		:accrualPeriodicity    => 'http://purl.org/dc/terms/accrualPeriodicity',
		:accrualPolicy         => 'http://purl.org/dc/terms/accrualPolicy',
		:alternative           => 'http://purl.org/dc/terms/alternative',
		:audience              => 'http://purl.org/dc/terms/audience',
		:available             => 'http://purl.org/dc/terms/available',
		:bibliographicCitation => 'http://purl.org/dc/terms/bibliographicCitation',
		:conformsTo            => 'http://purl.org/dc/terms/conformsTo',
		:created               => 'http://purl.org/dc/terms/created',
		:dateAccepted          => 'http://purl.org/dc/terms/dateAccepted',
		:dateCopyrighted       => 'http://purl.org/dc/terms/dateCopyrighted',
		:dateSubmitted         => 'http://purl.org/dc/terms/dateSubmitted',
		:educationLevel        => 'http://purl.org/dc/terms/educationLevel',
		:extent                => 'http://purl.org/dc/terms/extent',
		:hasFormat             => 'http://purl.org/dc/terms/hasFormat',
		:hasPart               => 'http://purl.org/dc/terms/hasPart',
		:hasVersion            => 'http://purl.org/dc/terms/hasVersion',
		:instructionalMethod   => 'http://purl.org/dc/terms/instructionalMethod',
		:isFormatOf            => 'http://purl.org/dc/terms/isFormatOf',
		:isPartOf              => 'http://purl.org/dc/terms/isPartOf',
		:isReferencedBy        => 'http://purl.org/dc/terms/isReferencedBy',
		:isReplacedBy          => 'http://purl.org/dc/terms/isReplacedBy',
		:isRequiredBy          => 'http://purl.org/dc/terms/isRequiredBy',
		:issued                => 'http://purl.org/dc/terms/issued',
		:isVersionOf           => 'http://purl.org/dc/terms/isVersionOf',
		:license               => 'http://purl.org/dc/terms/license',
		:mediator              => 'http://purl.org/dc/terms/mediator',
		:medium                => 'http://purl.org/dc/terms/medium',
		:modified              => 'http://purl.org/dc/terms/modified',
		:provenance            => 'http://purl.org/dc/terms/provenance',
		:references            => 'http://purl.org/dc/terms/references',
		:replaces              => 'http://purl.org/dc/terms/replaces',
		:requires              => 'http://purl.org/dc/terms/requires',
		:rightsHolder          => 'http://purl.org/dc/terms/rightsHolder',
		:spatial               => 'http://purl.org/dc/terms/spatial',
		:tableOfContents       => 'http://purl.org/dc/terms/tableOfContents',
		:temporal              => 'http://purl.org/dc/terms/temporal',
		:valid                 => 'http://purl.org/dc/terms/valid',

		# DCMI Types
		:Collection            => 'http://purl.org/dc/dcmitype/Collection',
		:Dataset               => 'http://purl.org/dc/dcmitype/Dataset',
		:Event                 => 'http://purl.org/dc/dcmitype/Event',
		:Image                 => 'http://purl.org/dc/dcmitype/Image',
		:InteractiveResource   => 'http://purl.org/dc/dcmitype/InteractiveResource',
		:MovingImage           => 'http://purl.org/dc/dcmitype/MovingImage',
		:PhysicalObject        => 'http://purl.org/dc/dcmitype/PhysicalObject',
		:Service               => 'http://purl.org/dc/dcmitype/Service',
		:Software              => 'http://purl.org/dc/dcmitype/Software',
		:Sound                 => 'http://purl.org/dc/dcmitype/Sound',
		:StillImage            => 'http://purl.org/dc/dcmitype/StillImage',
		:Text                  => 'http://purl.org/dc/dcmitype/Text',
	}
	
	DEFAULT_VOCABULARIES = %w[
		http://purl.org/dc/elements/1.1/
		http://purl.org/dc/terms/
		http://purl.org/dc/dcmitype/
		http://www.w3.org/1999/02/22-rdf-syntax-ns
		http://www.w3.org/2000/01/rdf-schema
	]


	# Schemas for the ThingFish RDF metastore
	module Schemas
		UUID = Redland::Namespace.new( 'urn:uuid:' )
		
		THINGFISH_URL  = 'http://opensource.laika.com/rdf/2007/02/thingfish-schema#'
		THINGFISH_NS = Redland::Namespace.new( THINGFISH_URL )
	end
	
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new RDF Metastore that will use the given +datadir+ and +spooldir+ for
	### its store and for any temporary files, respectively.
	### 
	### The +config+ options supported depend on what features you've
	### compiled into your Redland library, and which store you choose. 
	### 
	### Common options:
	### 
	### [:store]
	###   The type of store to use. See http://librdf.org/docs/storage.html if you're not
	###   sure which one you should use. Defaults to the in-memory 'hashes' store.
	###
	### The type of store you've chosen will dictate which further options are 
	### accessible/required:
	### 
	### For the 'hashes' store:
	### 
	### [:hash_type]
	###   The type of hash store to use (+memory+ or +bdb+).
	def initialize( datadir, spooldir, config={} )
		self.log.debug "Initializing an RDF metastore with options: %p" % [config]
		opts = DEFAULT_OPTIONS.merge( config[:options] || {} )

		# Extract the type and name of the store out of the options hash, then build an
		# option string from the remaining items
		storetype = opts.delete( :store )
		name = opts.delete( :name )
		opts[:dir] = datadir.to_s if datadir
		optstring = make_optstring( opts )

		self.log.debug "Creating a %p store named %p, with options = %p" %
			[ storetype, name, optstring ]
		@store = Redland::TripleStore.new( storetype, name, optstring )
		@model = Redland::Model.new( @store )

		super
	end


	######
	public
	######

	attr_reader :store, :model
	

	### Returns +true+ if the given +uuid+ exists in the metastore.
	def has_uuid?( uuid )
		uuid_urn = Schemas::UUID[ uuid.to_s ]

		statements = @model.find( uuid_urn, nil, nil )
		self.log.debug "Got statements: %p" % [ statements ]
		
		return statements.empty? ? false : true
	end
	

	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		prop_url = map_property( propname )

		statements = @model.find( uuid_urn, prop_url, nil )
		self.log.debug "Got statements: %p" % [ statements.collect {|s| s.to_s } ]
		
		self.log.debug "Statements array is %sempty." % [ statements.empty? ? "" : "not "]
		return statements.empty? ? false : true
	end


	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		prop_url = map_property( propname )

		res = @model.create_resource( uuid_urn )
		
		res.update_property( prop_url, value )
	end

	
	### MetaStore API: Set the properties associated with the given +uuid+ to
	### those in the provided +hash+, eliminating any others already set.
	def set_properties( uuid, hash )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		resource = @model.create_resource( uuid_urn )

		resource.delete_properties

		hash.each do |propname, value|
			prop_url = map_property( propname )
			resource.update_property( prop_url, value )
		end
	end
	

	### Merge the properties in the provided +hash+ with those associated with
	### the given +uuid+.
	def update_properties( uuid, hash )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		resource = @model.create_resource( uuid_urn )

		hash.each do |propname, value|
			prop_url = map_property( propname )
			resource.update_property( prop_url, value )
		end
	end
	

	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		prop_url = map_property( propname )

		res = @model.create_resource( uuid_urn )

		property = res.get_property( prop_url ) or return nil
		return property.to_s
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		
		res = @model.create_resource( uuid_urn )
		
		proplist = {}
		res.get_properties do |prop, value|
			key = unmap_uri( prop.uri )
			self.log.debug "Property is: %p" % [ key ]
			
			if proplist[key]
				if proplist[key].is_a?( Array )
					proplist[key] << value.to_s
				else
					proplist[key] = [ proplist[key], value.to_s ]
				end
			else
				proplist[key] = value.to_s
			end
		end
		
		self.log.debug "Returning propset: %p" % [proplist]
		return proplist
	end
	
	
	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		prop_url = map_property( propname )

		res = @model.create_resource( uuid_urn )
		res.delete_property( prop_url )
	end
	
	
	### MetaStore API: Removes the specified +properties+ associated with the given +uuid+.
	def delete_properties( uuid, *properties )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		res = @model.create_resource( uuid_urn )

		properties.collect {|prop| map_property(prop) }.each do |prop_url|
			res.delete_property( prop_url )
		end
	end	


	### MetaStore API: Removes all predicates for a given +uuid+.
	### There is no difference between removing all predicates for a given
	### subject and removing the subject itself in an RDF model.
	def delete_resource( uuid )
		uuid_urn = Schemas::UUID[ uuid.to_s ]
		res = @model.create_resource( uuid_urn )
		res.delete_properties
	end


	### MetaStore API: Return all property keys in store
	def get_all_property_keys
		predicates = Set.new
		
		# I don't know how to do this any other way than a full scan. Surely there
		# must be one?
		@model.triples do |subj, pred, obj|
			predicates.add( pred )
		end
		
		return predicates.to_a.collect {|uri| unmap_uri(uri) }
	end
	

	### Return a uniquified Array of all values in the metastore for the
	### specified +prop+.
	def get_all_property_values( prop )
		prop_url = map_property( prop )
		values = Set.new
		
		@model.find( nil, prop_url, nil ) do |_, _, object|
			values.add( object.value )
		end
		
		return values.to_a
	end


	### Return an array of uuids whose metadata matched the criteria specified
	### by +hash+. The criteria should be key-value pairs which describe
	### exact metadata pairs. This is an exact match search.
	def find_by_exact_properties( hash )
		self.log.debug "Searching for %p" % [ hash ]
		
		uris = hash.reject {|k,v| v.nil? }.inject(nil) do |ary, pair|
			key, value = *pair
			property = map_property( key.to_s )
			self.log.debug "  finding %s nodes in the model whose object is %p" %
				[ property, value ]

			stmts = @model.find( nil, property, value )
			self.log.debug "  found %d matching statements" % [ stmts.length ]

			if ary
				nodes = stmts.collect {|stmt| stmt.subject.uri.to_s }
				self.log.debug "  intersecting %p with %p" % [ nodes, ary ]
				ary &= nodes
			else
				nodes = stmts.collect {|stmt| stmt.subject.uri.to_s }
				self.log.debug "  initializing resource array with %p" % [ nodes ]
				ary = nodes
			end
			
			ary
		end
		
		self.log.debug "Search yielded %d resulting resource URIs" % [ uris.length ]

		return [] unless uris
		return uris.collect {|uri| uri[ UUID_URN, 1 ] }
	end
	

	### Return an array of uuids whose metadata matched the criteria
	### specified by +hash+. The criteria should be key-value pairs which describe
	### partial metadata pairs.  This is a wildcard search.
	def find_by_matching_properties( hash )
		
		# Flatten the hash of query args into an array of tuples
		pairs = []
		hash.reject {|_,val| val.nil? }.each do |key, vals|
			[vals].flatten.each do |val|
				pairs << [ key, val ]
			end
		end
		
		self.log.debug "Building a query using pairs: %p" % [ pairs ]
		predicates = Set.new
		filters = Set.new

		# Create a set of predicates and filters out of the tuples.
		pairs.each do |key, pattern|
			property = map_property( key )
			predicates.add( "<#{property.uri}> ?#{key}" )
			
			re = self.glob_to_regexp( pattern )
			string_re = re.inspect[ %r{/(.*)/i}, 1 ]
			filters.add( %Q:FILTER regex(?#{key}, "#{string_re}", "i"): )
		end

		# Now combine the predicates and filters into a SPARQL query
		querystring = QUERY_TEMPLATE % [
			predicates.to_a.join( " ;\n" ),
			filters.to_a.join( " .\n" ),
		  ]
		self.log.debug "SPARQL query is: \n%s" % [ querystring ]
		query = Redland::Query.new( querystring )
		res = @model.query_execute( query )

		# Map results into simple UUID strings
		uuids = []
		until res.finished?
			urn = res.binding_value_by_name( 'uuid' )
			self.log.debug "Get result URN: %s" % [ urn.uri ]
			uuids << urn.uri.to_uuid
			res.next
		end
		
		return uuids
	end
	

	### Output the current model to the log
	def log_model
		self.log.debug do
			dumplines = []
			@model.triples {|s,p,o| dumplines << "#{s}:#{p}:#{o}" }
			
			"Model is: \n  %s" % [ dumplines.join("\n  ") ]
		end
	end
	


	#######
	private
	#######

	### Map the given +propname+ into a registered namespace, falling back to 
	### the ThingFish namespace if it doesn't exist in any registered schema.
	def map_property( propname )
		return ThingFish::RdfMetaStore.map_to_predicate( propname )
	end
	

	### Map the URI back into a simple keyword Symbol.
	def unmap_uri( uri )
		uristring = uri.to_s.sub( /^\[([^\]]+)\]$/ ) { $1 }
		uri = URI.parse( uristring )
		property = uri.fragment || uri.path[ %r{/(\w+)$}, 1 ] or
			raise "Couldn't map %p into a property" % [ uristring ]
		return property.to_sym
	end
	

	### Make a Redland-style option string from an option hash.
	def make_optstring( options )

		# Eliminate pairs we need to control ourselves
		options[:new] = 'yes'
		options[:write] = 'yes'
		
		# Transform keys: :hash_type => 'hash-type'
		pairs = options.collect {|k,v| [k.to_s.gsub(/_/, '-'), v] }

		# Sort them by key, quote them, and then catenate them all together with commas
		return pairs.
			sort_by {|key,_| key }.
			collect {|pair| "%s='%s'" % pair }.join( ',' )
	end
	
end # class ThingFish::RdfMetaStore

# vim: set nosta noet ts=4 sw=4:

