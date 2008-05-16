#!/usr/bin/ruby 
# 
# A collection of standard filters for the manual generation tasklib.
# $Id$
# 
# Authors:
#   Michael Granger <ged@FaerieMUD.org>
# 
# 

# Dependencies deferred until #initialize


### Avoid declaring the class if the tasklib hasn't been loaded yet.
unless Object.const_defined?( :Manual )
	raise LoadError, "not intended for standalone use: try the 'manual.rb' rake tasklib"
end



### A filter for inline example code or command-line sessions -- does
### syntax-highlighting (via CodeRay), syntax-checking for some languages, and
### captioning.
### 
### Examples are enclosed in XML processing instructions like so:
###
###   <?example {language: ruby, testable: true, caption: "A fine example"} ?>
###      a = 1
###      puts a
###   <?end example ?>
###
### This will be pulled out into a preformatted section in the HTML,
### highlighted as Ruby source, checked for valid syntax, and annotated with
### the specified caption. Valid keys in the example PI are:
### 
### language::
###   Specifies which (machine) language the example is in.
### testable::
###	  If set and there is a testing function for the given language, run it and append
###	  any errors to the output.
### caption::
###   A small blurb to put below the pulled-out example in the HTML.
class ExamplesFilter < Manual::Page::Filter
	
	DEFAULTS = {
		:language     => :ruby,
		:line_numbers => :inline,
		:tab_width    => 4,
		:hint         => :debug,
		:testable     => true
	}

	# PI	   ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>'
	ExamplePI = %r{
		<\?
			example				# Instruction Target
			(?:					# Optional instruction body
			\s+
			(					# [$1]
				[^?]*			# Anything but a question mark
				|				# -or-
				\?(?!>)			# question mark not followed by a closing angle bracket
			)
			)?
		\?>
	  }x
	
	EndPI = %r{ <\? end (?: \s+ example )? \s* \?> }x


	### Defer loading of dependenies until the filter is loaded
	def initialize( *args )
		begin
			require 'pathname'
			require 'strscan'
			require 'yaml'
			require 'uv'
			require 'rcodetools/xmpfilter'
			require 'digest/md5'
			require 'tmpdir'
		rescue LoadError => err
			unless Object.const_defined?( :Gem )
				require 'rubygems'
				retry
			end

			raise
		end
	end
	
	
	######
	public
	######

	### Process the given +source+ for <?example ... ?> processing-instructions, calling out
	def process( source, page, metadata )
		scanner = StringScanner.new( source )
		
		buffer = ''
		until scanner.eos?
			startpos = scanner.pos
			
			# If we find an example
			if scanner.skip_until( ExamplePI )
				contents = ''
				
				# Append the interstitial content to the buffer
				if ( scanner.pos - startpos > scanner.matched.length )
					offset = scanner.pos - scanner.matched.length - 1
					buffer << scanner.string[ startpos..offset ]
				end

				# Append everything up to it to the buffer and save the contents of
				# the tag
				params = scanner[1]
				
				# Now find the end of the example or complain
				contentpos = scanner.pos
				scanner.skip_until( EndPI ) or
					raise "Unterminated example at line %d" % 
						[ scanner[0..scanner.pos].count("\n") ]
				
				# Now build the example and append to the buffer
				if ( scanner.pos - contentpos > scanner.matched.length )
					offset = scanner.pos - scanner.matched.length - 1
					contents = scanner.string[ contentpos..offset ]
				end

				#$stderr.puts "Processing with params: %p, contents: %p" % [ params, contents ]
				buffer << self.process_example( params, contents )
			else
				break
			end

		end
		buffer << scanner.rest
		scanner.terminate
		
		return buffer
	end
	
	
	### Filter out 'example' macros, doing syntax highlighting, and running
	### 'testable' examples through a validation process appropriate to the
	### language the example is in.
	def process_example( params, body )
		options = self.parse_options( params )
		caption = options.delete( :caption )
		content = ''
		
		# Test it if it's testable
		if options[:testable]
			content = test_content( body, options[:language] )
		else
			content = body
		end

		# Strip trailing blank lines and syntax-highlight
		content = highlight( content.strip, options )
		caption = %{<div class="caption">} + caption.to_s + %{</div>} if caption

		return %{<notextile><div class="example">%s%s</div></notextile>} %
		 	[content, caption || '']
	end


	### Parse an options hash for filtering from the given +args+, which can either 
	### be a plain String, in which case it is assumed to be the name of the language the example 
	### is in, or a Hash of configuration options.
	def parse_options( args )
		args = "{ #{args} }" unless args.strip[0] == ?{
		args = YAML.load( args )

		# Convert to Symbol keys and value
		args.keys.each do |k|
			newval = args.delete( k )
			next if newval.nil? || (newval.respond_to?(:size) && newval.size == 0)
			args[ k.to_sym ] = newval.respond_to?( :to_sym ) ? newval.to_sym : newval
		end
		return DEFAULTS.merge( args )
	end
	

	### Test the given +content+ with a rule specific to the given +language+.
	def test_content( body, language )
		case language.to_sym
		when :ruby
			return self.test_ruby_content( body )

		when :yaml
			return self.test_yaml_content( body )

		else
			return body
		end
	end
	
		
	### Test the specified Ruby content for valid syntax
	def test_ruby_content( source )
		# $stderr.puts "Testing ruby content..."
		libdir = Pathname.new( __FILE__ ).dirname.parent.parent.parent + 'lib'

		options = Rcodetools::XMPFilter::INITIALIZE_OPTS.dup
		options[:include_paths] << libdir.to_s

		rval = Rcodetools::XMPFilter.run( source, options )

		# $stderr.puts "test output: ", rval
		return rval.join
	rescue Exception => err
		return "%s while testing %s: %s\n  %s" %
			[ err.class.name, sourcefile, err.message, err.backtrace.join("\n  ") ]
	end
	
	
	### Test the specified YAML content for valid syntax
	def test_yaml_content( source )
		YAML.load( source )
	rescue YAML::Error => err
		return "# Invalid YAML: " + err.message + "\n" + source
	else
		return source
	end
	
	

	# Highlights the given +content+ in language +lang+.
	def highlight( content, options )
		lang = options.delete( :language ).to_s
		if Uv.syntaxes.include?( lang )
			return Uv.parse( content, "xhtml", lang, true, "deveiate")
		else
			begin
				require 'amatch'
				pat = Amatch::PairDistance.new( lang )
				matches = Uv.syntaxes.
					collect {|syntax| [pat.match(syntax), syntax] }.
					sort_by {|tuple| tuple[0] }.
					reverse
				puts matches[ 0..5 ].inspect
				puts "No syntax called '#{lang}'.",
					"Perhaps you meant one of: ",
					*(matches[ 0..5 ].collect {|m| "  #{m[1]}" })
			rescue => err
				$stderr.puts err.message, err.backtrace.join("\n  ")
				raise "No UV syntax called '#{lang}'."
			end
		end
	end
	
end





