# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'thingfish' unless defined?( Thingfish )


class Thingfish

	# Hides your class's ::new method and adds a +pure_virtual+ method generator for
	# defining API methods. If subclasses of your class don't provide implementations of
	# "pure_virtual" methods, NotImplementedErrors will be raised if they are called.
	#
	#   # AbstractClass
	#   class MyBaseClass
	#       extend Thingfish::AbstractClass
	#
	#       # Define a method that will raise a NotImplementedError if called
	#       pure_virtual :api_method
	#   end
	#
	module AbstractClass

		### Extension callback -- mark the extended object's .new as private
		def self::extended( mod )
			super
			mod.class_eval { private_class_method :new }
		end


		### Define one or more "virtual" methods which will raise
		### NotImplementedErrors when called via a concrete subclass.
		def pure_virtual( *syms )
			syms.each do |sym|
				define_method( sym ) do |*args|
					raise ::NotImplementedError,
					"%p does not provide an implementation of #%s" % [ self.class, sym ],
					caller(1)
				end
			end
		end


		### Inheritance callback -- Turn subclasses' .new methods back to public.
		def inherited( subclass )
			subclass.module_eval { public_class_method :new }
			super
		end

	end # module AbstractClass


	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       extend Thingfish::MethodUtilities
	#
	#       singleton_attr_accessor :types
	#       singleton_method_alias :kinds, :types
	#   end
	#
	#   MyClass.types = [ :pheno, :proto, :stereo ]
	#   MyClass.kinds # => [:pheno, :proto, :stereo]
	#
	module MethodUtilities

		### Creates instance variables and corresponding methods that return their
		### values for each of the specified +symbols+ in the singleton of the
		### declaring object (e.g., class instance variables and methods if declared
		### in a Class).
		def singleton_attr_reader( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_reader, sym )
			end
		end

		### Creates methods that allow assignment to the attributes of the singleton
		### of the declaring object that correspond to the specified +symbols+.
		def singleton_attr_writer( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_writer, sym )
			end
		end

		### Creates readers and writers that allow assignment to the attributes of
		### the singleton of the declaring object that correspond to the specified
		### +symbols+.
		def singleton_attr_accessor( *symbols )
			symbols.each do |sym|
				singleton_class.__send__( :attr_accessor, sym )
			end
		end

		### Creates an alias for the +original+ method named +newname+.
		def singleton_method_alias( newname, original )
			singleton_class.__send__( :alias_method, newname, original )
		end


		### Create a reader in the form of a predicate for the given +attrname+.
		def attr_predicate( attrname )
			attrname = attrname.to_s.chomp( '?' )
			define_method( "#{attrname}?" ) do
				instance_variable_get( "@#{attrname}" ) ? true : false
			end
		end


		### Create a reader in the form of a predicate for the given +attrname+
		### as well as a regular writer method.
		def attr_predicate_accessor( attrname )
			attrname = attrname.to_s.chomp( '?' )
			attr_writer( attrname )
			attr_predicate( attrname )
		end

	end # module MethodUtilities


	# A collection of data-manipulation functions.
	module DataUtilities

		###############
		module_function
		###############

		### Recursively copy the specified +obj+ and return the result.
		def deep_copy( obj )

			# Handle mocks during testing
			return obj if obj.class.name == 'RSpec::Mocks::Mock'

			return case obj
				when NilClass, Numeric, TrueClass, FalseClass, Symbol, Module, Encoding
					obj

				when Array
					obj.map {|o| deep_copy(o) }

				when Hash
					newhash = {}
					newhash.default_proc = obj.default_proc if obj.default_proc
					obj.each do |k,v|
						newhash[ deep_copy(k) ] = deep_copy( v )
					end
					newhash

				else
					obj.clone
				end
		end

	end # module DataUtilities


	# A collection of functions for dealing with object IDs.
	module OIDUtilities

		#########
		protected
		#########

		### Generate a new object ID.
		def make_object_id
			return normalize_oid( SecureRandom.uuid )
		end


		### Normalize the given +oid+.
		def normalize_oid( oid )
			return oid.to_s.downcase
		end

	end # module OIDUtilities


end # module Thingfish

# vim: set nosta noet ts=4 sw=4:

