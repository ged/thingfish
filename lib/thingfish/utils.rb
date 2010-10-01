#!/usr/bin/env ruby

require 'forwardable'
require 'logger'
require 'erb'

require 'thingfish'
require 'thingfish/constants'
require 'thingfish/mixins'


#
# A collection of little utility classes used elsewhere throughout the code
#
# == Synopsis
#
#   require 'thingfish/utils'
#
#   # Table (case-insensitive hash)
#   headers = ThingFish::Table.new
#   headers['User-Agent'] = 'PornBrowser 1.1.5'
#   headers['user-agent']  # => 'PornBrowser 1.1.5'
#   headers[:user_agent]   # => 'PornBrowser 1.1.5'
#   headers.user_agent     # => 'PornBrowser 1.1.5'
#
# == Description
#
# This module includes a collection of little utility classes:
#
# === ThingFish::Table
#
# A case-insensitive multivalue hash that allows access via Symbol or String.
#
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
# Please see the file LICENSE in the top-level directory for licensing details.
#
module ThingFish # :nodoc:

	### A case-insensitive multivalue hash that allows access via Symbol or String.
	class Table
		extend Forwardable
		include ThingFish::Constants,
			ThingFish::Loggable,
			ThingFish::HtmlInspectableObject

		KEYED_METHODS = [ :"[]", :"[]=", :delete, :fetch, :has_key?, :include?, :member?, :store ]


		### Auto-generate methods which call the given +delegate+ after normalizing
		### their first argument via +normalize_key+
		def self::def_normalized_delegators( delegate, *syms )
			syms.each do |methodname|
				define_method( methodname ) do |key, *args|
					nkey = normalize_key( key )
					instance_variable_get( delegate ).
						__send__( methodname, nkey, *args )
				end
			end
		end


		### Create a new ThingFish::Table using the given +hash+ for initial
		### values.
		def initialize( initial_values={} )
			@hash = {}
			initial_values.each {|k,v| self.append(k => v) }
		end


		### Make sure +@hash+ is unique on Table duplications.
		def initialize_copy( orig_table ) # :nodoc:
			@hash = orig_table.to_hash
		end


		######
		public
		######

		# Delegate a handful of methods to the underlying Hash after normalizing
		# the key.
		def_normalized_delegators :@hash, *KEYED_METHODS


		# Delegate some methods to the underlying Hash
		begin
			unoverridden_methods = Hash.instance_methods(false).collect {|mname| mname.to_sym }
			def_delegators :@hash, *( unoverridden_methods - KEYED_METHODS )
		end


		### Append the keys and values in the given +hash+ to the table, transforming
		### each value into an array if there was an existing value for the same key.
		def append( hash )
			self.merge!( hash ) do |key,origval,newval|
				[ origval, newval ].flatten
			end
		end


		### Return the Table as RFC822 headers in a String
		def to_s
			@hash.collect do |header,value|
				Array( value ).collect {|val|
					"%s: %s" % [
						normalize_header( header ),
						val
					]
				}
			end.flatten.sort.join( "\r\n" ) + "\r\n"
		end


		### Iterate over the table contents yielding each as an RFC822 header.
		def each_header
			@hash.each do |header, value|
				Array( value ).each do |val|
					yield( normalize_header(header), val.to_s )
				end
			end
		end


		### Return the Table as a hash.
		def to_h
			@hash.dup
		end
		alias_method :to_hash, :to_h


		### Merge +other_table+ into the receiver.
		def merge!( other_table, &merge_callback )
			nhash = normalize_hash( other_table.to_hash )
			@hash.merge!( nhash, &merge_callback )
		end
		alias_method :update!, :merge!


		### Return a new table which is the result of merging the receiver
		### with +other_table+ in the same fashion as Hash#merge. If the optional
		### +merge_callback+ block is provided, it is called whenever there is a
		### key collision between the two.
		def merge( other_table, &merge_callback ) # :yields: key, original_value, new_value
			other = self.dup
			other.merge!( other_table, &merge_callback )
			return other
		end
		alias_method :update, :merge


		### Return an array containing the values associated with the given
		### keys.
		def values_at( *keys )
			@hash.values_at( *(keys.collect {|k| normalize_key(k)}) )
		end


		#########
		protected
		#########

		### Proxy method: handle getting/setting headers via methods instead of the
		### index operator.
		def method_missing( sym, *args )
			# work magic
			return super unless sym.to_s =~ /^([a-z]\w+)(=)?$/

			# If it's an assignment, the (=)? will have matched
			key, assignment = $1, $2

			method_body = nil
			if assignment
				method_body = self.make_setter( key )
			else
				method_body = self.make_getter( key )
			end

			self.class.send( :define_method, sym, &method_body )
			return self.method( sym ).call( *args )
		end


		### Create a Proc that will act as a setter for the given key
		def make_setter( key )
			return Proc.new {|new_value| self[ key ] = new_value }
		end


		### Create a Proc that will act as a getter for the given key
		def make_getter( key )
			return Proc.new { self[key] }
		end


		#######
		private
		#######

		### Return a copy of +hash+ with all of its keys normalized by #normalize_key.
		def normalize_hash( hash )
			hash = hash.dup
			hash.keys.each do |key|
				nkey = normalize_key( key )
				hash[ nkey ] = hash.delete( key ) if key != nkey
			end

			return hash
		end


		### Normalize the given key to equivalence
		def normalize_key( key )
			key.to_s.downcase.gsub('-', '_').to_sym
		end


		### Return the given key as an RFC822-style header label
		def normalize_header( key )
			key.to_s.split( '_' ).collect {|part| part.capitalize }.join( '-' )
		end


	end # class Table


	### A alternate formatter for Logger instances.
	class LogFormatter < Logger::Formatter

		# The format to output unless debugging is turned on
		DEFAULT_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s -- %7$s\n"

		# The format to output if debugging is turned on
		DEFAULT_DEBUG_FORMAT = "[%1$s.%2$06d %3$d/%4$s] %5$5s {%6$s} -- %7$s\n"


		### Initialize the formatter with a reference to the logger so it can check for log level.
		def initialize( logger, format=nil, debug=nil ) # :notnew:
			@logger       = logger
			@format       = format || DEFAULT_FORMAT
			@debug_format = debug  || DEFAULT_DEBUG_FORMAT

			super()
		end

		######
		public
		######

		# The Logger object associated with the formatter
		attr_accessor :logger

		# The logging format string
		attr_accessor :format

		# The logging format string that's used when outputting in debug mode
		attr_accessor :debug_format


		### Log using either the DEBUG_FORMAT if the associated logger is at ::DEBUG level or
		### using FORMAT if it's anything less verbose.
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity,                                                     # %5$s
				progname,                                                     # %6$s
				msg                                                           # %7$s
			]

			if @logger.level == Logger::DEBUG
				return self.debug_format % args
			else
				return self.format % args
			end
		end
	end # class LogFormatter


	# 
	# An alternate formatter for Logger instances that outputs +div+ HTML
	# fragments.
	# 
	# == Usage
	# 
	#   require 'thingfish/utils'
	#   ThingFish.logger.formatter = ThingFish::HtmlLogFormatter.new( ThingFish.logger )
	# 
	# == Version
	#
	#  $Id$
	#
	# == Authors
	#
	# * Michael Granger <ged@FaerieMUD.org>
	#
	# :include: LICENSE
	#
	#--
	#
	# Please see the file LICENSE in the 'docs' directory for licensing details.
	#
	class HtmlLogFormatter < Logger::Formatter
		include ERB::Util  # for html_escape()

		# The default HTML fragment that'll be used as the template for each log message.
		HTML_LOG_FORMAT = %q{
		<div class="log-message %5$s">
			<span class="log-time">%1$s.%2$06d</span>
			[
				<span class="log-pid">%3$d</span>
				/
				<span class="log-tid">%4$s</span>
			]
			<span class="log-level">%5$s</span>
			:
			<span class="log-name">%6$s</span>
			<span class="log-message-text">%7$s</span>
		</div>
		}

		### Override the logging formats with ones that generate HTML fragments
		def initialize( logger, format=HTML_LOG_FORMAT ) # :notnew:
			@logger = logger
			@format = format
			super()
		end


		######
		public
		######

		# The HTML fragment that will be used as a format() string for the log
		attr_accessor :format


		### Return a log message composed out of the arguments formatted using the
		### formatter's format string
		def call( severity, time, progname, msg )
			args = [
				time.strftime( '%Y-%m-%d %H:%M:%S' ),                         # %1$s
				time.usec,                                                    # %2$d
				Process.pid,                                                  # %3$d
				Thread.current == Thread.main ? 'main' : Thread.object_id,    # %4$s
				severity.downcase,                                            # %5$s
				progname,                                                     # %6$s
				html_escape( msg ).gsub(/\n/, '<br />')                       # %7$s
			]

			return self.format % args
		end

	end # class HtmlLogFormatter

end # module ThingFish

# vim: set nosta noet ts=4 sw=4:

