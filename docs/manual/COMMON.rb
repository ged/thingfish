#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'coderay'
require 'pathname'
require 'rcodetools/xmpfilter'
require 'digest/md5'
require 'tmpdir'

require 'rote/filters/base'

class ExampleFilter < Rote::Filters::MacroFilter
	
	DEFAULTS = {
		:language     => :ruby,
		:line_numbers => :inline,
		:tab_width    => 4,
		:hint         => :debug,
		:testable     => true
	}

    MACRO_RE = /
		^\s*
		\#\: 					# beginning of macro start
			([a-z]+)			# macro name
			(?:\#([^#]*))?		# optional macro arguments
		\#\s*?\n?				# end of macro start
		(.*?)\s*				# macro body
		\#\:\1\#(?:\2\#)?		# macro end
		\s*$
	/mx
	
	
	### Figure out where Rcodetools' XMPFilter lives (this changed at around 0.7.0)
    def initialize( macro_re=MACRO_RE )
		super( [], macro_re )
		@filter_mod = defined?( Rcodetools ) ? Rcodetools::XMPFilter : XMPFilter
	end
	
	
	### Filter out 'example' macros, doing syntax highlighting, and running 'testable' examples
	### through a validation process appropriate to the language the example is in.
	def macro_example( args, body, raw )
		args = YAML.load( args )
		caption = args.delete( 'caption' )
		options = self.parse_options( args )
		content = ''
		
		# Test it if it's testable
		if options[:testable]
			tmpdir = Pathname.new( Dir.tmpdir )
			examplefile = tmpdir + Digest::MD5.hexdigest( body )
			examplefile.open( File::WRONLY|File::CREAT, 0600 ) {|fh| fh.write(body) }

			content = test_content( examplefile, options[:language] )
		else
			content = body
		end

		# Strip trailing blank lines and syntax-highlight
		content = highlight( content.strip, options )
		caption = %{<div class="caption">} + caption + %{</div>} if caption

		return %{<div class="example">%s%s</div>} % [content, caption || '']
	ensure
		examplefile.delete if examplefile
	end


	### Parse an options hash for filtering from the given +args+, which can either 
	### be a plain String, in which case it is assumed to be the name of the language the example 
	### is in, or a Hash of configuration options.
	def parse_options( args )
		case args
		when Hash
			# Convert to Symbol keys and value
			args.keys.each do |k|
				newval = args.delete( k )
				args[ k.to_sym ] = newval.respond_to?( :to_sym ) ? newval.to_sym : newval
			end
			return DEFAULTS.merge( args )
		when String
			return DEFAULTS.merge({ 'language' => args })
		else
			raise ArgumentError, "Malformed example options '%p'" % [args]
		end
	end
	

	### Test the given +content+ with a rule specific to the given +language+.
	def test_content( examplefile, language )
		case language.to_sym
		when :ruby
			lines = test_ruby_content( examplefile )
			return lines.join

		when :yaml
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
		# $stderr.puts "Testing ruby content..."
		libdir = Pathname.new( __FILE__ ).dirname.parent.parent + 'lib'

		options = @filter_mod::INITIALIZE_OPTS.dup
			
		options[:include_paths] << libdir.to_s
		rval = @filter_mod.run( sourcefile.read, options )
		# $stderr.puts "test output: ", rval

		return rval
	rescue Exception => err
		return "%s while testing %s: %s\n  %s" %
			[ err.class.name, sourcefile, err.message, err.backtrace.join("\n  ") ]
	end
	
	

	# Highlights the given +content+ in language +lang+.
	def highlight( content, options )
		lang = options.delete( :language )
		scanner = CodeRay.scan( content, lang.to_sym )

		options[:wrap] = :div
		return scanner.html( options )
	end
end

page_filter ExampleFilter.new


#####################################################################
###	N A V I G A T I O N   S E C T I O N S
#####################################################################

def find_page_title( pathname )
	pathname.each_line do |line|
		if m = /@page_title\s*=\s*(["'])([^'"]*?)\1/.match(line)
			return m[2]
		end
	end

	return pathname.basename( '.page' ).to_s.sub( /^\d+\./, '' ).
		split( /[_-]+/ ).
		collect {|word| word.capitalize }.
		join( ' ' )
end


@navsections = []
@section_title = 'Manual'

manualdir = Pathname.new( __FILE__ ).dirname
srcdir = manualdir + 'src'

srcdir.each_entry do |section|
	next if section.basename.to_s =~ /^\./

	path = srcdir + section
	next unless path.directory?

	# Set up the title of the section based on the directory name
	sectiontitle = section.to_s.sub( /^\d+\./, '' ).gsub( /_/, ' ' )

	# Find pages in this section and skip the section is empty
	subpages = path.entries.
		select {|pagefile| pagefile.extname == '.page' }.
		reject {|pagefile| pagefile.to_s =~ /index\.page/ }.
		collect {|pagefile| section + pagefile }
	next if subpages.empty?

	# Figure out where the section link should point -- either the index.page if there
	# is one, or the first subpage if not
	indexfile = path + 'index.page'
	if indexfile.exist?
		sectionhref = section + 'index.html'
	elsif 
		sectionhref = (section + subpages.first.basename('.page')).to_s + '.html'
	end

	# Now transform the sub-pages to path + title
	subpages.collect! do |page|
		pagepath = page.to_s.sub( /\.page$/, '.html' )
		pagetitle = find_page_title( srcdir + page )
		[ pagepath, pagetitle ]
	end

	#                 sectiontitle, sectionhref, subpages
	@navsections << [ sectiontitle, sectionhref, subpages ]
end


