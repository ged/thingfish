# 
# Manual-generation Rake tasks and classes
# $Id$
# 
# Authors:
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
# 
# This was born out of a frustration with other static HTML generation modules
# and systems. I've tried webby, webgen, rote, staticweb, staticmatic, and
# nanoc, but I didn't find any of them really suitable (except rote, which was
# excellent but apparently isn't maintained and has a fundamental
# incompatibilty with Rake because of some questionable monkeypatching.)
# 

require 'pathname'
require 'singleton'
require 'rake/tasklib'
require 'erb'


### Namespace for Manual-generation classes
module Manual

	### Manual page-generation class
	class Page

		### An abstract filter class for manual content transformation.
		class Filter
			include Singleton

			# A list of inheriting classes, keyed by normalized name
			@derivatives = {}
			class << self; attr_reader :derivatives; end

			### Inheritance callback -- keep track of all inheriting classes for
			### later.
			def self::inherited( subclass )
				key = subclass.name.
					sub( /^.*::/, '' ).
					gsub( /[^[:alpha:]]+/, '_' ).
					downcase.
					sub( /filter$/, '' )

				self.derivatives[ key ] = subclass
				self.derivatives[ key.to_sym ] = subclass

				super
			end


			### Export any static resources required by this filter to the given +output_dir+.
			def export_resources( output_dir )
				# No-op by default
			end
			

			### Process the +page+'s source with the filter and return the altered content.
			def process( source, page, metadata )
				raise NotImplementedError,
					"%s does not implement the #process method" % [ self.class.name ]
			end
		end


		### The default page configuration if none is specified.
		DEFAULT_CONFIG = {
			'filters' => [ 'textile', 'erb' ],
			'layout'  => 'default.page',
			'cleanup' => true,
		  }.freeze

		# Pattern to match a source page with a YAML header
		PAGE_WITH_YAML_HEADER = /
			\A---\s*$	# It should should start with three hyphens
			(.*?)		# ...have some YAML stuff
			^---\s*$	# then have another three-hyphen line,
			(.*)\Z		# then the rest of the document
		  /xm

		# Options to pass to libtidy
		TIDY_OPTIONS = {
			:show_warnings     => true,
			:indent            => true,
			:indent_attributes => false,
			:indent_spaces     => 4,
			:vertical_space    => true,
			:tab_size          => 4,
			:wrap_attributes   => true,
			:wrap              => 100,
			:char_encoding     => 'utf8'
		  }


		### Create a new page-generator for the given +sourcefile+, which will use
		### ones of the templates in +layouts_dir+ as a wrapper. The +basepath+ 
		### is the path to the base output directory.
		def initialize( sourcefile, layouts_dir, basepath='.' )
			@sourcefile  = Pathname.new( sourcefile )
			@layouts_dir = Pathname.new( layouts_dir )
			@basepath    = basepath

			rawsource = @sourcefile.read
			@config, @source = self.read_page_config( rawsource )

			# $stderr.puts "Config is: %p" % [@config],
			# 	"Source is: %p" % [ @source[0,100] ]
			@filters = self.load_filters( @config['filters'] )

			super()
		end


		######
		public
		######
		
		# The relative path to the base directory, for prepending to page paths
		attr_reader :basepath
		
		# The Pathname object that specifys the page source file
		attr_reader :sourcefile
		
		# The configured layouts directory as a Pathname object.
		attr_reader :layouts_dir
		
		# The page configuration, as read from its YAML header
		attr_reader :config
		
		# The raw source of the page
		attr_reader :source
		
		# The filters the page will use to render itself
		attr_reader :filters
		

		### Generate HTML output from the page and return it.
		def generate( metadata )
			content = self.generate_content( @source, metadata )

			templatepath = @layouts_dir + 'default.page'
			template = ERB.new( templatepath.read )
			page = self

			html = template.result( binding() )
			
			# Use Tidy to clean up the html if 'cleanup' is turned on, but remove the Tidy
			# meta-generator propaganda/advertising.
			html = self.cleanup( html ).sub( %r:<meta name="generator"[^>]*tidy[^>]*/>:im, '' ) if
				self.config['cleanup']
				
			return html
		end


		### Return the page title as specified in the YAML options
		def title
			return self.config['title'] || self.sourcefile.basename
		end
		
		
		### Run the various filters on the given input and return the transformed
		### content.
		def generate_content( input, metadata )
			return @filters.inject( input ) do |source, filter|
				filter.process( source, self, metadata )
			end
		end


		### Trim the YAML header from the provided page +source+, convert it to
		### a Ruby object, and return it.
		def read_page_config( source )
			unless source =~ PAGE_WITH_YAML_HEADER
				return DEFAULT_CONFIG.dup, source
			end
			
			pageconfig = YAML.load( $1 )
			source = $2
			
			return DEFAULT_CONFIG.merge( pageconfig ), source
		end
		

		### Clean up and return the given HTML +source+.
		def cleanup( source )
			require 'tidy'

			Tidy.path = '/usr/lib/libtidy.dylib'
			Tidy.open( TIDY_OPTIONS ) do |tidy|
				tidy.options.output_xhtml = true

				xml = tidy.clean( source )
				log( tidy.errors ) if tidy.errors
				trace tidy.diagnostics
				return xml
			end
		rescue LoadError => err
			trace "No cleanup: " + err.message
			return source
		end
		

		### Get (singleton) instances of the filters named in +filterlist+ and return them.
		def load_filters( filterlist )
			filterlist.flatten.collect do |key|
				raise ArgumentError, "filter '#{key}' is not loaded" unless
					Manual::Page::Filter.derivatives.key?( key )
				Manual::Page::Filter.derivatives[ key ].instance
			end
		end

	end


	### A catalog of Manual::Page objects that can be referenced by various criteria.
	class PageCatalog

		### Create a new PageCatalog that will load Manual::Page objects for .page files 
		### in the specified +sourcedir+.
		def initialize( sourcedir, layoutsdir )			
			@sourcedir = sourcedir
			@layoutsdir = layoutsdir
			
			@pages = []
			@path_index = {}
			@title_index = {}
			@hierarchy = {}
			
			self.find_and_load_pages
		end
		
		attr_reader :path_index, :title_index, :heirachy, :pages
		
		
		# {
		# 	'Introduction' => <intro page obj>,
		# 	'Developers Guide' => {
		# 		'' => <index page obj>,
		# 		'Connecting' => <connecting page obj>
		# 	}
		# }
		# 
		# heirarchy.each do |title, page_or_section|
		# 	if page_or_section.section?
		# 		<a href="page_or_section[''].path">
		# 	else
		# 		<a href="page.path">page.title</a>
		# 	end
		# 	
		# end
		# 
		
		######
		public
		######

		# The Array of all Manual::Page objects
		attr_reader :pages
		
		
		### Find all .page files under the configured +sourcedir+ and create a new
		### Manual::Page object for each one.
		def find_and_load_pages
			Pathname.glob( @sourcedir + '**/*.page' ).each do |pagefile|
				path_to_base = pagefile.dirname.relative_path_from( @sourcedir )

				page = Manual::Page.new( pagefile, @layoutsdir, path_to_base )

				@pages << page
				@path_index[ pagefile ] = page
				@title_index[ page.title ] = page
				
				# Place the page in the page hierarchy by using inject to find and/or create the 
				# necessary subhashes. The last run of inject will return the leaf hash in which
				# the page will live
				hierpath = pagefile.relative_path_from( @sourcedir )
				section = hierpath.dirname.split[1..-1].inject( @hierarchy ) do |hier, component|
					hier[ component ] ||= {}
					hier[ component ]
				end

				# 'index.page' files serve as the configuration for the section in which they
				# live, so they get treated specially.
				if pagefile.basename('.page') == 'index'
					section[ nil ] = page
				else
					section[ page.title ] = page
				end
			end
		end
		
	end


	### A Textile filter for the manual generation tasklib, implemented using RedCloth.
	class TextileFilter < Manual::Page::Filter

		### Load RedCloth when the filter is first created
		def initialize( *args )
			require 'redcloth'
			super
		end
		

		### Process the given +source+ as Textile and return the resulting HTML
		### fragment.
		def process( source, *ignored )
			return RedCloth.new( source ).to_html
		end

	end


	### An ERB filter for the manual generation tasklib, implemented using Erubis.
	class ErbFilter < Manual::Page::Filter

		### Process the given +source+ as ERB and return the resulting HTML
		### fragment.
		def process( source, page, metadata )
			template_name = page.sourcefile.basename
			template = ERB.new( source )
			return template.result( binding() )
		end

	end


	### Manual generation task library
	class GenTask < Rake::TaskLib
		
		# Default values for task config variables
		DEFAULT_NAME         = :manual
		DEFAULT_BASE_DIR     = Pathname.new( 'docs/manual' )
		DEFAULT_SOURCE_DIR   = 'source'
		DEFAULT_LAYOUTS_DIR  = 'layouts'
		DEFAULT_OUTPUT_DIR   = 'output'
		DEFAULT_RESOURCE_DIR = 'resources'
		DEFAULT_LIB_DIR      = 'lib'
		DEFAULT_METADATA     = OpenStruct.new
		

		### Define a new manual-generation task with the given +name+.
		def initialize( name=:manual )
			@name           = name

			@source_dir		= DEFAULT_SOURCE_DIR
			@layouts_dir	= DEFAULT_LAYOUTS_DIR
			@output_dir		= DEFAULT_OUTPUT_DIR
			@resource_dir	= DEFAULT_RESOURCE_DIR
			@lib_dir	    = DEFAULT_LIB_DIR
			@metadata		= DEFAULT_METADATA
			
			yield( self ) if block_given?
			
			self.define
		end
		
		
		######
		public
		######

		attr_accessor :base_dir,
			:source_dir,
			:layouts_dir,
			:output_dir,
			:resource_dir,
			:lib_dir,
			:metadata

		attr_reader :name


		### Set up the tasks for building the manual
		def define

			# Set up a description if the caller hasn't already defined one
			unless Rake.application.last_comment
				desc "Generate the manual"
			end

			# Make Pathnames of the directories relative to the base_dir
			basedir     = Pathname.new( @base_dir )
			sourcedir   = basedir + @source_dir
			layoutsdir  = basedir + @layouts_dir
			outputdir   = basedir + @output_dir
			resourcedir = basedir + @resource_dir
			libdir      = basedir + @lib_dir

			load_filter_libraries( libdir )
			catalog = Manual::PageCatalog.new( sourcedir, layoutsdir )
			
			# require 'pp'
			# pp catalog

			# Declare the tasks outside the namespace that point in
			task @name => "#@name:build"
			task "clobber_#@name" => "#@name:clobber"

			namespace( self.name ) do
				setup_resource_copy_tasks( resourcedir, outputdir )
				manual_pages = setup_page_conversion_tasks( sourcedir, outputdir, catalog )
				
				desc "Build the manual"
				task :build => [ :copy_resources, :generate_pages ]
				
				task :clobber do
					RakeFileUtils.verbose( $verbose ) do
						rm_f manual_pages.to_a
					end
					remove_dir( outputdir ) if ( outputdir + '.buildtime' ).exist?
				end
				
				desc "Remove any previously-generated parts of the manual and rebuild it"
				task :rebuild => [ :clobber, :build ]
	        end

		end # def define
		
		
		### Load the filter libraries provided in the given +libdir+
		def load_filter_libraries( libdir )
			Pathname.glob( libdir + '*.rb' ) do |filterlib|
				trace "  loading filter library #{filterlib}"
				require( filterlib )
			end
		end


		### Set up the main HTML-generation task that will convert files in the given +sourcedir+ to
		### HTML in the +outputdir+
		def setup_page_conversion_tasks( sourcedir, outputdir, catalog )
			
			# we need to figure out what HTML pages need to be generated so we can set up the
			# dependency that causes the rule to be fired for each one when the task is invoked.
			manual_sources = FileList[ catalog.path_index.keys.map {|pn| pn.to_s} ]
			trace "   found %d source files" % [ manual_sources.length ]
			
			# Map .page files to their equivalent .html output
			html_pathmap = "%%{%s,%s}X.html" % [ sourcedir, outputdir ]
			manual_pages = manual_sources.pathmap( html_pathmap )
			trace "Mapping sources like so: \n  %p -> %p" %
				[ manual_sources.first, manual_pages.first ]
			
			# Output directory task
			directory( outputdir.to_s )
			file outputdir.to_s do
				touch outputdir + '.buildtime'
			end
	
			# Rule to generate .html files from .page files
			rule( 
				%r{#{outputdir}/.*\.html$} => [
					proc {|name| name.sub(/\.[^.]+$/, '.page').sub( outputdir, sourcedir) },
					outputdir.to_s
			 	]) do |task|
			
				source = Pathname.new( task.source )
				target = Pathname.new( task.name )
				log "  #{ source } -> #{ target }"
					
				page = catalog.path_index[ source ]
				trace "  page object is: %p" % [ page ]
					
				target.dirname.mkpath
				target.open( File::WRONLY|File::CREAT|File::TRUNC ) do |io|
					io.write( page.generate(metadata) )
				end
			end
			
			# Group all the manual page output files targets into a containing task
			desc "Generate any pages of the manual that have changed"
			task :generate_pages => manual_pages
			return manual_pages
		end
		
		
		### Copy method for resources -- passed as a block to the various file tasks that copy
		### resources to the output directory.
		def copy_resource( task )
			source = task.prerequisites[ 1 ]
			target = task.name
			
			when_writing do
				log "  #{source} -> #{target}"
				mkpath File.dirname( target )
				cp source, target, :verbose => $trace
			end
		end
			
		
		### Set up a rule for copying files from the resources directory to the output dir.
		def setup_resource_copy_tasks( resourcedir, outputdir )
			resources = FileList[ resourcedir + '**/*.{js,css,png,gif,jpg,html}' ]
			resources.exclude( /\.svn/ )
			target_pathmap = "%%{%s,%s}p" % [ resourcedir, outputdir ]
			targets = resources.pathmap( target_pathmap )
			copier = self.method( :copy_resource ).to_proc
			
			# Create a file task to copy each file to the output directory
			resources.each_with_index do |resource, i|
				file( targets[i] => [ outputdir.to_s, resource ], &copier )
			end

			# Now group all the resource file tasks into a containing task
			desc "Copy manual resources to the output directory"
			task :copy_resources => targets
		end
		
	end # class Manual::GenTask
	
end
