#!/usr/bin/env ruby

require 'pathname'
require 'set'
require 'redleaf'
require 'uuidtools'
require 'ipaddr'
require 'rational'
require 'socket'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/metastore'
require 'thingfish/metastore/simple'
require 'thingfish/constants'

# ThingFish::RdfMetaStore -- a simple metastore plugin for ThingFish that
# stores metadata in an RDF knowledgebase using Redleaf.
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#
class ThingFish::RdfMetaStore < ThingFish::SimpleMetaStore
	include ThingFish::Constants,
		ThingFish::Constants::Patterns,
		Redleaf::Constants::CommonNamespaces

	# Schemas for the ThingFish RDF metastore
	#
	module Schemas
		THINGFISH_URL  = 'http://opensource.laika.com/rdf/2009/04/thingfish-schema#'
		THINGFISH_NS = Redleaf::Namespace.new( THINGFISH_URL )
	end
	include Schemas

	# Default options for the store, regardless of backend.
	#
	DEFAULT_OPTIONS = {
		:store     => 'hashes',
		:hash_type => 'memory',
		:label     => 'rdf-metastore'
	}

	# The SPARQL query template to use for exact searching
	EXACT_QUERY_TEMPLATE = <<-END
		SELECT ?uuid
		WHERE
		{
			?uuid %s .
		}
	END

	# The SPARQL query template to use for regex match searching
	REGEX_QUERY_TEMPLATE = <<-END
		SELECT ?uuid
		WHERE
		{
			?uuid %s .
			%s
		}
	END

	# The SPARQL query to use when selecting arbitrary sets of triples
	SORTED_TRIPLES_QUERY = %q{
		SELECT ?uuid, ?pred, ?obj
		WHERE { ?uuid ?pred ?obj }
		ORDER BY ?uuid
	}


	### Register some types with Redleaf's node-conversion tables

	# There's almost certainly an actual URI for IP addresses, but I 
	# can't find it
	IANA_NUMBERS = Redleaf::Namespace.new( 'http://www.iana.org/numbers/' )

	Redleaf::NodeUtils.register_new_class( IPAddr, IANA_NUMBERS[:ipaddr] ) do |addr|
		af = case addr.family
		     when Socket::AF_INET then "ipv4"
		     when Socket::AF_INET6 then "ipv6"
		     else "unknown" end
		ip = addr.to_string

		# Regretably the only way to actually get the mask_addr as a string
		mask = addr.send( :_to_string, addr.instance_variable_get(:@mask_addr) )

		"%s:%s/%s" % [ af, ip, mask ]
	end

	Redleaf::NodeUtils.register_new_type( IANA_NUMBERS[:ipaddr] ) do |literal_string|
		IPAddr.new( literal_string[/.*:(.*)/, 1] )
	end

	# Convert Rationals to their floating-point approximation, and Time objects to
	# xsd:dateTimes. :FIXME: Times should probably be converted to UTC times.
	Redleaf::NodeUtils.register_new_class( Rational, XSD[:decimal], :to_f )
	Redleaf::NodeUtils.register_new_class( Time, XSD[:dateTime], :to_s )


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
	###   sure which one you should use. Defaults to the 'hashes' store.
	###
	### The type of store you've chosen will dictate which further options are
	### accessible/required.
	###
	def initialize( datadir, spooldir, options={} )
		opts = DEFAULT_OPTIONS.merge( options )

		storetype  = opts.delete( :store )
		storelabel = opts.delete( :label )
		opts[ :dir ] ||= datadir.to_s
		opts[ :new ] ||= false

		Redleaf.logger = ThingFish.logger

		unless Redleaf::Store.backends.include?( storetype )
			raise ThingFish::MetaStoreError,
				"Your Redland installation does not support the %s store." % [ storetype ]
		end

		self.log.debug "Creating Redleaf store: %s" % [ storetype ]
		@store = Redleaf::Store.create( storetype, storelabel, opts )
		@graph = @store.graph

		super
	end



	######
	public
	######

	### Execute a block in the scope of a transaction, committing it when the block returns.
	### If an exception is raised in the block, the transaction is aborted. This is a
	### no-op by default, but left to specific metastores to provide a functional
	### implementation if it is useful/desired.
	def transaction
		rval = yield
		@store.sync if @store.persistent?
		return rval
	end


	### MetaStore API: Return the property associated with +uuid+ specified by
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		return @graph.objects( uuid_urn(uuid), map_property(propname) ).first
	end


	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	###
	### For the RDF simple store, all predicates are mapped to the THINGFISH namespace.
	def get_properties( uuid )
		return @graph[ uuid_urn(uuid), nil, nil ].inject({}) do |hash, statement|
			name = unmap_property( statement.predicate ).to_sym
			hash[ name ] = statement.object
			hash
		end
	end


	### MetaStore API: Returns a list of all property keys in the database.
	def get_all_property_keys
		predicates = Set.new
		@graph.statements.collect {|st| predicates.add(st.predicate) }
		return predicates.collect {|pred| unmap_property(pred) }
	end


	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		values = Set.new
		@graph[ nil, map_property(key), nil ].each do |st|
			values.add( st.object )
		end

		return values.to_a
	end


	### NOTE: Aliased #find_by_exact_properties to #find_by_matching_properties for 
	###       case-insensitivity

	### MetaStore API: Return an array of tuples of the form:
	###   [ UUID, { :key => «value» } ]
	### whose metadata exactly matches the key-value pairs in +hash+. If the 
	### optional +order+, +limit+, and +offset+ are given, use them to limit the result set.
	# def find_by_exact_properties( hash, order=[], limit=DEFAULT_LIMIT, offset=0 )
	# 	self.log.debug "Searching for %p" % [ hash ]
	# 
	# 	# Flatten the hash of query args into an array of tuples
	# 	pairs = []
	# 	hash.reject {|_,val| val.nil? }.each do |key, vals|
	# 		[vals].flatten.each do |val|
	# 			pairs << [ key, val ]
	# 		end
	# 	end
	# 
	# 	# Create a set of predicates and filters out of the tuples.
	# 	self.log.debug "Building a query using pairs: %p" % [ pairs ]
	# 	predicates = Set.new
	# 	pairs.each do |key, value|
	# 		property = map_property( key )
	# 		predicates.add( "<#{property}> #{Redleaf.make_literal_string(value)}" )
	# 	end
	# 
	# 	# Make the ORDER BY clause
	# 	orderattrs = []
	# 	order.each do |attrname|
	# 		property = map_property( attrname )
	# 		predicates.add( "<#{property}> ?#{attrname}" )
	# 		orderattrs << "?#{attrname}"
	# 	end
	# 	orderattrs << "?uuid"
	# 
	# 	# Now combine the predicates and filters into a SPARQL query
	# 	querystring = EXACT_QUERY_TEMPLATE % [ predicates.to_a.join(" ;\n") ]
	# 	querystring << "ORDER BY %s" % [ orderattrs.join(' ') ]
	# 	querystring << " LIMIT %d" % [ limit ] if limit
	# 	querystring << " OFFSET %d" % [ offset ] if offset.nonzero?
	# 
	# 	self.log.debug "SPARQL query is: \n%s" % [ querystring ]
	# 	uuids = @graph.query( querystring ) or return []
	# 
	# 	return self.make_uuid_tuples( uuids.collect {|row| row[:uuid] } )
	# end


	### MetaStore API: Return an array of uuids whose metadata matched the criteria
	### specified by +hash+. The criteria should be key-value pairs which describe
	### partial metadata pairs.  This is a wildcard search.
	def find_by_matching_properties( hash, order=[], limit=DEFAULT_LIMIT, offset=0 )

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
			predicates.add( "<#{property}> ?#{key}" )

			re = self.glob_to_regexp( pattern )
			string_re = re.inspect[ %r{/(.*)/i}, 1 ]
			filters.add( %Q:FILTER regex(?#{key}, "#{string_re}", "i"): )
		end

		# Make the ORDER BY clause
		orderattrs = []
		order.each do |attrname|
			property = map_property( attrname )
			predicates.add( "<#{property}> ?#{attrname}" )
			orderattrs << "?#{attrname}"
		end
		orderattrs << "?uuid"

		# Now combine the predicates and filters into a SPARQL query
		querystring = REGEX_QUERY_TEMPLATE % [
			predicates.to_a.join( " ;\n" ),
			filters.to_a.join( " .\n" ),
		  ]

		# Now combine the predicates and filters into a SPARQL query
		querystring << "ORDER BY %s" % [ orderattrs.join(' ') ]
		querystring << " LIMIT %d" % [ limit ] if limit.nonzero?
		querystring << " OFFSET %d" % [ offset ] if offset.nonzero?

		self.log.debug "SPARQL query is: \n%s" % [ querystring ]
		uuids = @graph.query( querystring ) or return []

		# Map results into simple UUID strings
		return self.make_uuid_tuples( uuids.collect {|row| row[:uuid] } )
	end
	alias_method :find_by_exact_properties, :find_by_matching_properties


	### Map an Array of UUIDs to an Array of tuples of the form returned by 
	### #find_by_exact_properties and #find_by_matching_properties.
	def make_uuid_tuples( uuids )
		return uuids.inject([]) do |results, uuid|
			props = @graph[ uuid, nil, nil ].inject({}) do |hash, stmt|
				self.log.debug "Injecting over predicates about %p: %p" % [ uuid, stmt ]
				hash[ unmap_property(stmt.predicate) ] = stmt.object
				hash
			end
			results << [ make_uuid_string(uuid), props ]
		end
	end


	### Metastore API: Yield all the metadata in the store one resource at a time
	def each_resource # :yields: uuid, properties_hash
		current_uuid = nil
		propset = nil

		res = @graph.query( SORTED_TRIPLES_QUERY ) or return

		res.each do |row|
			uuid = uuid_obj( row[:uuid] ).to_s
			key = unmap_property( row[:pred] )
			value = row[:obj]

			self.log.debug "Adding [%s -> %s] to the proplist for %s" %
				[ key, value, uuid ]

			# Yield the set of values found for the previous UUID if we're on to a
			# new one
			if uuid != current_uuid
				yield( current_uuid, propset ) unless current_uuid.nil?
				propset = {}
			end

			current_uuid = uuid
			propset[ key ] = value
		end

		# Yield the final set
		yield( current_uuid, propset ) unless current_uuid.nil?
	end


	### MetaStore API: Set the property associated with +uuid+ specified by
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		# properties are stored uniquely.
		value = '' if value.nil?
		@graph << [ uuid_urn(uuid), map_property(propname), value ]
	end


	### MetaStore API: Set the properties associated with the given +uuid+ to those
	### in the provided +propshash+.
	def set_properties( uuid, propshash )
		self.transaction do
			subject = uuid_urn( uuid )
			@graph.remove( [subject, nil, nil] )

			statements = propshash.inject([]) do |stmts, pair|
				pred, obj = *pair
				obj = '' if obj.nil?
				stmts << [ subject, THINGFISH_NS[pred], obj ]
				stmts
			end

			@graph.append( *statements )
		end
	end


	### MetaStore API: Merge the provided +propshash+ into the properties associated with the
	### given +uuid+.
	def update_properties( uuid, propshash )
		self.transaction do
			subject = uuid_urn( uuid )

			statements = propshash.inject([]) do |stmts, pair|
				pred, obj = *pair
				obj = '' if obj.nil?
				stmts << [ subject, map_property(pred), obj ]
				stmts
			end

			@graph.append( *statements )
		end
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		self.transaction do
			@graph.remove( [uuid_urn(uuid), map_property(propname), nil] ).first
		end
	end


	### MetaStore API: Removes the specified +properties+ associated with +uuid+ from the 
	### store.
	def delete_properties( uuid, *properties )
		subject = uuid_urn( uuid )
		self.transaction do
			properties.each do |propname|
				@graph.remove([ subject, map_property(propname), nil ])
			end
		end
	end


	### MetaStore API: Removes all references to the resource associated with +uuid+ from
	### the store.
	def delete_resource( uuid )
		self.transaction do
			@graph.remove([ uuid_urn(uuid), nil, nil ])
		end
	end


	### MetaStore API: Deletes all metadata from the store.
	def clear
		self.transaction do
			@graph.remove([ nil, nil, nil ])
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		return @graph.has_predicate_about?( uuid_urn(uuid), map_property(propname) )
	end


	### MetaStore API: Returns +true+ if the given +uuid+ exists in the metastore.
	def has_uuid?( uuid )
		return ! @graph[ uuid_urn(uuid), nil, nil ].empty?
	end


	### Metastore API: Dump all values in the store as a Hash keyed by UUID.
	def dump_store
		return @graph.inject({}) do |dumpstruct, statement|
			# Skip triples that aren't about UUIDs
			next unless statement.subject.is_a?( URI ) &&
				statement.subject.opaque =~ /^uuid:/

			keyword = unmap_property( statement.predicate )
			uuid = statement.subject.opaque[/.*:(.*)/, 1]

			dumpstruct[ uuid ] ||= {}
			dumpstruct[ uuid ][ keyword ] = statement.object.to_s

			dumpstruct
		end
	end


	### Metastore API: Replace all values in the store with those in the given hash.
	def load_store( hash )
		self.clear

		hash.each do |uuid, properties|
			uuid_urn = make_uuid_urn( uuid )

			properties.each do |propname, value|
				predicate = map_property( propname )
				value = '' if value.nil?
				@graph << [ uuid_urn, predicate, value ]
			end
		end

	end


	#######
	private
	#######

	### Make a UUID URN out of the given +uuid+.
	def make_uuid_urn( uuid )
		return URI("urn:uuid:#{uuid}")
	end
	alias_method :uuid_urn, :make_uuid_urn


	### Make a UUID object out of a UUID URN.
	def make_uuid_object( urn )
		return UUIDTools::UUID.parse( make_uuid_string(urn) )
	end
	alias_method :uuid_obj, :make_uuid_object


	### Make a UUID string out of a UUID URN.
	def make_uuid_string( urn )
		raise ArgumentError,
			"%p doesn't have an opaque attribute" % [urn] unless urn.respond_to?( :opaque )
		return urn.opaque[/.*:(.*)/, 1]
	end
	alias_method :uuid_obj, :make_uuid_object


	### Map the specified +propname+ to a predicate URI and return it.
	def map_property( propname )
		# :TODO: Decide how predicates should actually be mapped
		return THINGFISH_NS[propname]
	end


	### Unmap the specified +predicate+ to a property name and return it.
	def unmap_property( predicate )
		# :TODO: Decide how predicates should actually be unmapped
		return (predicate.fragment || Pathname( predicate.path ).basename).to_sym
	end

end # class ThingFish::RdfMetaStore


__END__

# vim: set nosta noet ts=4 sw=4:

