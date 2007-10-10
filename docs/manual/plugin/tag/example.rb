# 
# Example plugin for the ThingFish manual
# 

begin
	require 'rbconfig'
	require 'pathname'
	require 'rcodetools/xmpfilter'
	require 'coderay'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


# Includes a file verbatim. All HTML special characters are escaped.
class ExampleTag < Tags::DefaultTag

	XMP_OPTIONS = {
		:interpreter       => "ruby",
		:options 			=> [],
		:min_codeline_size => 50,
		:libs              => [],
		:evals             => [],
		:include_paths     => [],
		:dump              => nil,
		:wd                => nil,
		:warnings          => true,
		:use_parentheses   => true,
		:column            => nil,
		:output_stdout     => true,
	}


	infos( :name => 'Tag/Example',
		:author => "Monkeys",
		:summary => "Include a example with syntax highlighting, narrowing, and testing"
	)

	param 'filename', nil, 'The name of the file which should be included (relative to the ' +
		'file specifying the tag).'
	param 'processOutput', true, 'The file content will be scanned for tags if true'
	param 'escapeHTML', true, 'Special HTML characters in the file content will be escaped if true'

	param 'language', nil, 'Name of language that should be used for syntax highlighting ' +
		"and testing."
	param 'tab_width', 4, 'The number of spaces to use for literal tabs in the output.'
	param 'hint', false, 'Show styling hints in the titles of the spans used to do highlighting'
	param 'line_numbers', 'inline', 'Syntax highlighting option'

	param 'testable', true, "Whether or not the example should be tested"
	param 'narrow', nil, "If this is set, it is used as a criteria to narrow the " +
		"region of the file that is included"
	param 'caption', nil, 'The caption that should appear below the example, if any'

	set_mandatory 'filename', true
	set_mandatory 'language', true

	register_tag 'example'


	### Figure out where Rcodetools' XMPFilter lives (this changed at around 0.7.0)
	def initialize( *args )
		super
		@filter_mod = defined?( Rcodetools ) ? Rcodetools::XMPFilter : XMPFilter
	end
	

	### Process the specified +tag+ in the given +chain+.
	def process_tag( tag, chain )
		@process_output = param( 'processOutput' )
		language = param('language')
		tab_width = param('tab_width')
		hint = param('hint')
		line_numbers = param('line_numbers')
		testable = param('testable')
		narrow = param('narrow')
		content = ''

		examplefile = Pathname.new( param('filename') )
		srcfile = Pathname.new( chain.first.node_info[:src] )
		
		unless examplefile.absolute?
			examplefile = srcfile.dirname + examplefile
		end

		# Test it if it's testable
		content = test_content( examplefile, language ) if testable

		# Strip trailing blank lines and syntax-highlight
		content = highlight( content.strip, language, tab_width, hint, line_numbers )
		caption = %{<div class="caption">} + param('caption') + %{</div>} if param('caption')

		return %{<div class="example">%s%s</div>} % [content, caption || '']

	rescue SystemCallError => err
		log( :error ) {
			"<%s> specified in <%s>: (%s) %s\n  %s" % [
				examplefile.relative_path_from( srcfile ),
				srcfile.relative_path_from( Pathname.getwd ),
				err.class.name,
				err.message,
				err.backtrace.join( "\n  " )
			]
		}
	end


	### Return the given +content+ with any HTML entities escaped.
	def escape_html( content )
		content.
			gsub( /&/n, '&amp;' ).
			gsub( /\"/n, '&quot;' ).
			gsub( />/n, '&gt;' ).
			gsub( /</n, '&lt;' )
	end


	### Test the given +content+ with a rule specific to the given +language+.
	def test_content( examplefile, language )
		case language
		when 'ruby'
			lines = test_ruby_content( examplefile )
			return lines.join

		when 'yaml'
			require 'yaml'
			source = examplefile.read
			YAML.load( source )
			return source

		else
			return examplefile.read
		end
	end
	
	
	### Test the specified Ruby content for valid syntax
	def test_ruby_content( sourcefile )
		basedir = Pathname.new( __FILE__ ) + '../../../../..'
		libdir = basedir + 'lib'
		log( :debug ) { "Appending " + libdir + " to $LOAD_PATH" }

		options = @filter_mod::INITIALIZE_OPTS.dup
			
		options[:include_paths] << libdir.to_s
		return @filter_mod.run( sourcefile.read, options )
		
	rescue Exception => err
		log( :error ) {
			"%s while testing %s: %s\n  %s" %
			[ err.class.name, sourcefile, err.message, err.backtrace.join("\n  ") ]
		}
		
		return sourcefile.read
	end
	
	

	# Highlights the given +content+ in language +lang+.
	def highlight( content, lang, tab_width, hint, line_numbers )
		options = { :wrap => :div, :tab_width => tab_width }
		options[:line_numbers] = line_numbers.to_sym if line_numbers
		options[:hint] = hint.to_sym if hint

		scanner = CodeRay.scan( content, lang.to_sym )
		return scanner.html( options )
	end

end
