#!/usr/bin/ruby
#
# ThingFish::MarshalledMetaStore-- a metastore plugin for ThingFish.
#
# == Synopsis
#
#   require 'thingfish/metastore'
#
#   ms = ThingFish::MetaStore.create( "marshalled" )
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
#  * Michael Granger <mgranger@laika.com>
#  * Mahlon E. Smith <mahlon@laika.com>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

begin
	require 'pathname'
	require 'pstore'
	require 'lockfile'

	require 'thingfish'
	require 'thingfish/exceptions'
	require 'thingfish/metastore/simple'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

### ThingFish::MarshalledMetaStore-- a metastore plugin for ThingFish
class ThingFish::MarshalledMetaStore < ThingFish::SimpleMetaStore

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The default options to use when creating locks. See the docs for Lockfile for
	# more info on what these values mean
	DEFAULT_LOCK_OPTIONS = {
		:retries        => nil,		# retry forever
		:sleep_inc      => 2,
		:min_sleep      => 2,
		:max_sleep      => 32,
		:max_age        => 1024,
		:suspend        => 64,
		:refresh        => 8,
		:timeout        => nil,		# Wait for a lock forever
		:poll_retries   => 16,
		:poll_max_sleep => 0.08,
		:dont_clean     => false,
		:dont_sweep     => false,
		:debug			=> false,
	  }
	
	
	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new MarshalledMetaStore
	def initialize( datadir, spooldir, options={} )
		super

		datadir.mkpath
		@datafile = @datadir + 'metadata'

		@metadata  = PStore.new( @datafile.to_s )
		@lock_opts = @options[:lock] || DEFAULT_LOCK_OPTIONS
		@lock      = Lockfile.new( @datadir + 'metadata.lock' )
	end


	######
	public
	######

	### MetaStore API: Set the property associated with +uuid+ specified by 
	### +propname+ to the given +value+.
	def set_property( uuid, propname, value )
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ] ||= {}
				@metadata[ uuid.to_s ][ propname.to_sym ] = value
			end
		end
	end


	### MetaStore API: Set the properties associated with the given +uuid+ to those
	### in the provided +propshash+.
	def set_properties( uuid, propshash )
		props = propshash.dup
		props.each_key {|key| props[key.to_sym] = props.delete(key) }
		
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ] = props
			end
		end
	end
	
	
	### MetaStore API: Merge the provided +propshash+ into the properties associated with the 
	### given +uuid+.
	def update_properties( uuid, propshash )
		props = propshash.dup
		props.each_key {|key| props[key.to_sym] = props.delete(key) }
		
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ].merge!( props )
			end
		end
	end
	
	
	### MetaStore API: Return the property associated with +uuid+ specified by 
	### +propname+. Returns +nil+ if no such property exists.
	def get_property( uuid, propname )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ][ propname.to_sym ]
		end
	end

	
	### MetaStore API: Get the set of properties associated with the given +uuid+ as
	### a hashed keyed by property names as symbols.
	def get_properties( uuid )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ].clone
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has a property +propname+.
	def has_property?( uuid, propname )
		@metadata.transaction do
			@metadata[ uuid.to_s ] ||= {}
			return @metadata[ uuid.to_s ].key?( propname.to_sym )
		end
	end


	### MetaStore API: Returns +true+ if the given +uuid+ has any properties.
	def has_uuid?( uuid )
		@metadata.transaction do
			@metadata.root?( uuid.to_s )
		end
	end


	### MetaStore API: Removes +propname+ from given +uuid+
	def delete_property( uuid, propname )
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ] ||= {}
				return @metadata[ uuid.to_s ].delete( propname.to_sym ) ? true : false
			end
		end
	end
	
	
	### MetaStore API: Removes the properties specified by +propnames+ from those associated with
	### +uuid+.
	def delete_properties( uuid, *propnames )
		@lock.lock do
			@metadata.transaction do
				@metadata[ uuid.to_s ] ||= {}
				propnames.each do |propname|
					@metadata[ uuid.to_s ].delete( propname.to_sym )
				end
			end
		end
	end
	
	
	### MetaStore API: Removes all properties from given +uuid+
	def delete_resource( uuid )
		@lock.lock do
			@metadata.transaction do
				return 0 if @metadata[ uuid.to_s ].nil?
				count = @metadata[ uuid.to_s ].length
				@metadata.delete( uuid.to_s )
				return count
			end
		end
	end

	### MetaStore API: Return all property keys in store
	def get_all_property_keys

		# PStore doesn't implement a collect(), so we need a manual collector.
		keys = []

		@lock.lock do
			@metadata.transaction(true) do
				@metadata.roots.each do |uuid|
					keys << @metadata[ uuid ].keys
				end
			end
		end
		return keys.flatten.uniq
	end
	
	
	### MetaStore API: Return a uniquified Array of all values in the metastore for
	### the specified +key+.
	def get_all_property_values( key )
		values = []
		key    = key.to_sym

		@lock.lock do
			@metadata.transaction(true) do
				@metadata.roots.each do |uuid|
					values << @metadata[ uuid ][ key ]
				end
			end
		end
		return values.compact.uniq
	end
	
	
	### MetaStore API: Return an array of UUIDs whose metadata exactly matches the
	### key-value pairs in +hash+.
	def find_by_exact_properties( hash )
		uuids = hash.inject(nil) do |ary, pair|
			key, value = *pair
			key = key.to_sym

			matching_uuids = []
			key = key.to_sym
			@lock.lock do
				@metadata.transaction(true) do
					@metadata.roots.each do |uuid|
						matching_uuids << uuid if @metadata[ uuid ][ key ] == value
					end
				end
			end
			
			if ary
				ary &= matching_uuids
			else
				ary = matching_uuids
			end
			
			ary
		end
		
		return uuids ? uuids : []
	end


	### MetaStore API: Return an array of UUIDs whose metadata wildcard matches the
	### key-value pairs in +hash+.
	def find_by_matching_properties( hash )
		uuids = hash.inject(nil) do |ary, pair|
			key, pattern = *pair
			key = key.to_sym

			matching_uuids = []
			key = key.to_sym
			re = Regexp.new( '^' + pattern.to_s.gsub('*', '.*') + '$', Regexp::IGNORECASE )
						
			@lock.lock do
				@metadata.transaction(true) do
					@metadata.roots.each do |uuid|
						matching_uuids << uuid if re.match( @metadata[ uuid ][ key ] )
					end
				end
			end
			
			if ary
				ary &= matching_uuids
			else
				ary = matching_uuids
			end
			
			ary
		end
		
		return uuids ? uuids : []
	end
		
end # class ThingFish::MarshalledMetaStore

# vim: set nosta noet ts=4 sw=4:

