# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# encoding: utf-8

require 'thingfish' unless defined?( ThingFish )


module ThingFish

	# Hides your class's ::new method and adds a +pure_virtual+ method generator for
	# defining API methods. If subclasses of your class don't provide implementations of
	# "pure_virtual" methods, NotImplementedErrors will be raised if they are called.
	#
	#   # AbstractClass
	#   class MyBaseClass
	#       include ThingFish::AbstractClass
	#
	#       # Define a method that will raise a NotImplementedError if called
	#       pure_virtual :api_method
	#   end
	#
	module AbstractClass

		### Methods to be added to including classes
		module ClassMethods

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


			### Turn subclasses' new methods back to public.
			def inherited( subclass )
				subclass.module_eval { public_class_method :new }
				super
			end

		end # module ClassMethods


		### Inclusion callback
		def self::included( mod )
			super
			if mod.respond_to?( :new )
				mod.extend( ClassMethods )
				mod.module_eval { private_class_method :new }
			end
		end


	end # module AbstractClass


	# A collection of various delegation code-generators that can be used to define
	# delegation through other methods, to instance variables, etc.
	module Delegation

		###############
		module_function
		###############

		### Define the given +delegated_methods+ as delegators to the like-named method
		### of the return value of the +delegate_method+.
	###
		###    class MyClass
		###      extend ThingFish::Delegation
		###
		###      # Delegate the #bound?, #err, and #result2error methods to the connection
		###      # object returned by the #connection method. This allows the connection
		###      # to still be loaded on demand/overridden/etc.
		###      def_method_delegators :connection, :bound?, :err, :result2error
		###
		###      def connection
		###        @connection ||= self.connect
		###      end
		###   end
		###
		def def_method_delegators( delegate_method, *delegated_methods )
			delegated_methods.each do |name|
				body = make_method_delegator( delegate_method, name )
				define_method( name, &body )
			end
			end


		### Define the given +delegated_methods+ as delegators to the like-named method
		### of the specified +ivar+. This is pretty much identical with how 'Forwardable'
		### from the stdlib does delegation, but it's reimplemented here for consistency.
		###
		###    class MyClass
		###      extend ThingFish::Delegation
		###
		###      # Delegate the #each method to the @collection ivar
		###      def_ivar_delegators :@collection, :each
		###
		###    end
		###
		def def_ivar_delegators( ivar, *delegated_methods )
			delegated_methods.each do |name|
				body = make_ivar_delegator( ivar, name )
				define_method( name, &body )
			end
			end


		### Define the given +delegated_methods+ as delegators to the like-named class
		### method.
		def def_class_delegators( *delegated_methods )
			delegated_methods.each do |name|
				define_method( name ) do |*args|
					self.class.__send__( name, *args )
			end
			end
		end


		#######
		private
		#######

		### Make the body of a delegator method that will delegate to the +name+ method
		### of the object returned by the +delegate+ method.
		def make_method_delegator( delegate, name )
			error_frame = caller(5)[0]
			file, line = error_frame.split( ':', 2 )

			# Ruby can't parse obj.method=(*args), so we have to special-case setters...
			if name.to_s =~ /(\w+)=$/
				name = $1
				code = <<-END_CODE
				lambda {|*args| self.#{delegate}.#{name} = *args }
				END_CODE
				else
				code = <<-END_CODE
				lambda {|*args,&block| self.#{delegate}.#{name}(*args,&block) }
				END_CODE
				end

			return eval( code, nil, file, line.to_i )
				end


		### Make the body of a delegator method that will delegate calls to the +name+
		### method to the given +ivar+.
		def make_ivar_delegator( ivar, name )
			error_frame = caller(5)[0]
			file, line = error_frame.split( ':', 2 )

			# Ruby can't parse obj.method=(*args), so we have to special-case setters...
			if name.to_s =~ /(\w+)=$/
				name = $1
				code = <<-END_CODE
				lambda {|*args| #{ivar}.#{name} = *args }
				END_CODE
			else
				code = <<-END_CODE
				lambda {|*args,&block| #{ivar}.#{name}(*args,&block) }
				END_CODE
			end

			return eval( code, nil, file, line.to_i )
		end

	end # module Delegation


	# A collection of miscellaneous functions that are useful for manipulating
	# complex data structures.
	#
	#   include ThingFish::DataUtilities
	#   newhash = deep_copy( oldhash )
	#
	module DataUtilities

		###############
		module_function
		###############

		### Recursively copy the specified +obj+ and return the result.
		def deep_copy( obj )

			# Handle mocks during testing
			return obj if obj.class.name == 'RSpec::Mocks::Mock'

			return case obj
				when NilClass, Numeric, TrueClass, FalseClass, Symbol, Module
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


		### Create and return a Hash that will auto-vivify any values it is missing with
		### another auto-vivifying Hash.
		def autovivify( hash, key )
			hash[ key ] = Hash.new( &ThingFish::DataUtilities.method(:autovivify) )
			end


		### Return a version of the given +hash+ with its keys transformed
		### into Strings from whatever they were before.
		def stringify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				if val.is_a?( Hash )
					newhash[ key.to_s ] = stringify_keys( val )
				else
					newhash[ key.to_s ] = val
				end
			end

			return newhash
		end


		### Return a duplicate of the given +hash+ with its identifier-like keys
		### transformed into symbols from whatever they were before.
		def symbolify_keys( hash )
			newhash = {}

			hash.each do |key,val|
				keysym = key.to_s.dup.untaint.to_sym

				if val.is_a?( Hash )
					newhash[ keysym ] = symbolify_keys( val )
				else
					newhash[ keysym ] = val
				end
		end

			return newhash
		end
		alias_method :internify_keys, :symbolify_keys

	end # module DataUtilities


	# A collection of methods for declaring other methods.
	#
	#   class MyClass
	#       extend ThingFish::MethodUtilities
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


end # module ThingFish

# vim: set nosta noet ts=4 sw=4:

