# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'securerandom'

require 'thingfish' unless defined?( Thingfish )

module Thingfish

	# A collection of functions for dealing with object IDs.
	module Normalization

		###############
		module_function
		###############

		### Generate a new object ID.
		def make_object_id
			return normalize_oid( SecureRandom.uuid )
		end


		### Normalize the given +oid+.
		def normalize_oid( oid )
			return oid.to_s.downcase
		end


		### Return a copy of the given +collection+ after being normalized.
		def normalize_keys( collection )
			if collection.respond_to?( :keys )
				return collection.each_with_object({}) do |(key,val),new_hash|
					n_key = normalize_key( key )
					new_hash[ n_key ] = val
				end

			elsif collection.respond_to?( :map )
				return collection.map {|key| normalize_key(key) }
			end

			return nil
		end


		### Return a normalized copy of +key+.
		def normalize_key( key )
			return key.to_s.downcase.gsub( /[^\w:]+/, '_' )
		end

	end # module Normalization


end # module Thingfish

# vim: set nosta noet ts=4 sw=4:

