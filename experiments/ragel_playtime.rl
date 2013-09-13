# vim: set noet nosta sw=4 ts=4 ft=ragel :
#
# title:Mahl*%20Smith,(format:(image/jpeg|image/png),extent:<100|format:image/icns)
# 
# [
# 	['title', 'Mahl* Smith' ],
# 	[:or,
# 		['format', [:or, [
# 				'image/jpeg',
# 				'image/png'
# 			]],
# 		 [:lt, 'extent', '100'],
# 		],
# 		['format', 'image/icns']
# 	]
# ]


%%{
	machine filter_to_sexp;

	action set_mark { mark = p; debug "set mark to %d" % [ p ] }
	action key_end  { key = filter.extract( mark, p ); debug( key ); }
	action val_end  { debug("k:%p v:%p" % [ key, filter.extract(mark, p) ]) }

	action and { debug 'AND' }
	action or  { debug 'OR' }

	action popen  { pdepth = pdepth + 1 }
	action pclose { pdepth = pdepth - 1 }

	uri_valid_chars = ( [a-zA-z0-9\-*%\/\.] );  # anything else requires URI encoding

	popen  = '(' >popen;
	pclose = ')' >pclose;
	parens = ( popen | pclose );

	or     = '|' >or;
	and    = ',' >and;
	gt     = '>';
	lt     = '<';
	oper   = ( gt | lt );
	bool   = ( and | or );

	key    = ( [a-zA-Z0-9\-]+ . ':' ) >set_mark %key_end;
	value  = ( uri_valid_chars )+     >set_mark %val_end;

  	# TODO: friggen everything of consequence
	main:= key value ( bool key value )* %{ debug "filter complete"; filter.valid = true };

	# main:= |*
	#    key value => { filter.value = true };
	# *|;
}%%


require 'pp'

###
###
class QueryFilter

	# FIXME: what to do on parse errors?  raise?  or just set invalid?
	class Error < RuntimeError; end
	class ParseError < Error; end

	# Ragel accessors are injected into the class.
	%% write data;

	########################################################################
	### C L A S S   M E T H O D S
	########################################################################

	### Parse a filter string into an S-Expression.
	###
	def self::parse( filter_str )
		#ts = te = act = 0
		key = ''

		filter = new( filter_str )
		data   = filter.data

		mark = 0
		pdepth = 0
		sexp = []

		%% write init;
		eof = pe
		%% write exec;

		filter.valid = false if filter.valid && ! pdepth.zero?
		# raise ParseError, "Unmatched parenthesis" unless pdepth.zero?

		self.debug "%p" % [ filter ]
		filter.extract( 0, 5 )

		filter.instance_variable_set( :@sexp, sexp )
		return filter
	end

	def self::debug( msg )
		$stderr.puts "  #{msg}" if $DEBUG
	end


	########################################################################
	### I N S T A N C E   M E T H O D S
	########################################################################

	### Instantiate a new QueryFilter, provided a +filter+ string.
	###
	private_class_method :new
	def initialize( filter ) # :nodoc:
		@str   = filter
		@data  = filter.to_s.unpack( 'c*' )
		@valid = false
	end


	# The array of character values, as signed 8-bit integers.
	attr_reader :data

	# Is the filter string parsable?
	attr_accessor :valid

	### Stringify the filter (returning the original argument.)
	###
	def to_s
		return @str
	end


	### Return the S-Expression of the filter.
	###
	def to_sexp
		return @s_exp
	end


	### Inspection string.
	###
	def inspect
		return "<%s:0x%08x filter:%p valid:%p>" % [
			self.class.name,
			self.object_id * 2,
			self.to_s,
			self.valid
		]
	end


	### Given a start and ending scanner position,
	### return an ascii representation of the data slice.
	###
	def extract( start, fin )
		slice = @data[ start, fin ]
		return '' unless slice
		return slice.pack( 'c*' )
	end
end





while str = gets
	str.chomp!
	begin
		qf = QueryFilter.parse( str )

	rescue => err
		puts "%s -> %s" % [ err.class.name, err.message ]
	end
end

