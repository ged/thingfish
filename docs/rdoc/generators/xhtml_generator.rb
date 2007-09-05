
require 'pp'
require 'pathname'
require 'fileutils'
require 'erb'

require 'rdoc/options'
require 'rdoc/markup/simple_markup'
require 'rdoc/markup/simple_markup/to_html'
require 'rdoc/generators/xml_generator'

### RDoc toplevel namespace for generators
module Generators

	### Generate one file per class
	class XHTMLGenerator < XMLGenerator
		include ERB::Util

		GENERATOR_DIR = Pathname.new( __FILE__ ).expand_path.dirname


		# Standard generator factory
		def self::for( options )
			new( options )
		end


		### Initialize a few instance variables before we start
		def initialize( *args )
			@template = nil
			@template_dir = GENERATOR_DIR + 'template'
			
			@files      = []
			@classes    = []
			@hyperlinks = {}

			@basedir = Pathname.pwd.expand_path

			super
		end
		
		
		### Create the directories the generated docs will live in if
		### they don't already exist.
		def gen_sub_directories
			@outputdir.mkpath
		end
		

		### Copy over the stylesheet into the appropriate place in the
		### output directory.
		def write_style_sheet
			$stderr.puts "Copying over static files"
			staticfiles = %w[rdoc.css js images]
			staticfiles.each do |path|
				cp_r( @template_dir + path, '.', :verbose => true )
			end
		end
		
		

		### Build the initial indices and output objects
		### based on an array of TopLevel objects containing
		### the extracted information. 
		def generate( toplevels )
			@outputdir = Pathname.new( @options.op_dir ).expand_path( @basedir )

			toplevels.each do |toplevel|
				@files << HtmlFile.new(toplevel, @options, FILE_DIR)
			end

			RDoc::TopLevel.all_classes_and_modules.each do |cls|
				self.build_class_list( cls, @files[0], @outputdir.to_s )
			end

			generate_xhtml( @options, @files, @classes )
			
			cssfile = @template_dir + 'rdoc.css'
			FileUtils.copy cssfile, @outputdir
		rescue StandardError => err
			$stderr.puts "%s: %s\n  %s" % [ err.class.name, err.message, err.backtrace.join("\n  ") ]
		end


		def build_class_list( cls, html_file, class_dir )
			@classes << HtmlClass.new( cls, html_file, class_dir, @options )
			cls.each_classmodule do |mod|
				build_class_list( mod, html_file, class_dir )
			end
		end


		### Load the template
		def load_html_template
		end


		### Generate output
		def generate_xhtml( options, files, classes )
			files = gen_into( @files )
			classes = gen_into( @classes )

			classes_by_classname = classes.inject({}) {|hash, classinfo|
				hash[ classinfo['full_name'] ] = classinfo
				hash[ classinfo['full_name'] ][:outfile] =
					classinfo['full_name'].gsub( /::/, '/' ) + '.html'
				hash
			}

			files_by_path = files.inject({}) {|hash, fileinfo|
				hash[ fileinfo['full_path'] ] = fileinfo
				hash[ fileinfo['full_path'] ][:outfile] = 
					fileinfo['full_path'] + '.html'
				hash
			}
			
			self.write_style_sheet
			self.generate_index( options, files_by_path, classes_by_classname )
			self.generate_class_files( options, files_by_path, classes_by_classname )
			self.generate_file_files( options, files_by_path, classes_by_classname )
		end


		### Return a list of the documented modules sorted by salience first, then by name.
		def get_sorted_module_list( classes )
			nscounts = classes.keys.inject({}) do |counthash, name|
				toplevel = name.gsub( /::.*/, '' )
				counthash[toplevel] ||= 0
				counthash[toplevel] += 1
				
				counthash
			end

			# Sort based on how often the toplevel namespace occurs, and then on the name 
			# of the module -- this works for projects that put their stuff into a 
			# namespace, of course, but doesn't hurt if they don't.
			return classes.keys.sort_by do |name| 
				toplevel = name.gsub( /::.*/, '' )
				[
					nscounts[ toplevel ] * -1,
					name
				]
			end
		end
		
		
		### Generate an index page which lists all the classes which
		### are documented.
		def generate_index( options, files, classes )
			$stderr.puts "Rendering the index page..."
			template_src = ( @template_dir + 'index.rhtml' ).read
			template = ERB.new( template_src, nil, '<>' )
			
			modsort = self.get_sorted_module_list( classes )
			output = template.result( binding() )
			
			outfile = @basedir + @options.op_dir + 'index.html'
			$stderr.puts "Outputting to %s" % [outfile.expand_path]
			unless $dryrun
				outfile.open( 'w', 0644 ) do |fh|
					fh.print( output )
				end
			end
		end


		### Generate a documentation file for each class present in the
		### given hash of +classes+.
		def generate_class_files( options, files, classes )
			$stderr.puts "Generating class documentation"
			template_src = ( @template_dir + 'classpage.rhtml' ).read
			template = ERB.new( template_src, nil, '<>' )
			outputdir = @outputdir

			modsort = self.get_sorted_module_list( classes )

			classes.sort_by {|k,v| k }.each do |classname, classinfo|
				$stderr.puts "  working on %s (%s)" % [ classname, classinfo[:outfile] ]
				outfile = outputdir + classinfo[:outfile]
				rel_prefix = outputdir.relative_path_from( outfile.dirname )

				output = template.result( binding() )

				unless $dryrun
					outfile.dirname.mkpath
					outfile.open( 'w', 0644 ) do |ofh|
						ofh.print( output )
					end
				else
					$stderr.puts "  would have written %d bytes to %s" %
						[ output.length, outfile ]
				end
			end
		end


		### Generate a documentation file for each file present in the
		### given hash of +files+.
		def generate_file_files( options, files, classes )
			$stderr.puts "Generating file documentation"
			template_src = ( @template_dir + 'filepage.rhtml' ).read
			template = ERB.new( template_src, nil, '<>' )
			outputdir = @outputdir

			files.sort_by {|k,v| k }.each do |path, fileinfo|
				$stderr.puts "  working on %s (%s)" % [ path, fileinfo[:outfile] ]
				outfile = outputdir + fileinfo[:outfile]
				rel_prefix = outputdir.relative_path_from( outfile.dirname )

				output = template.result( binding() )

				unless $dryrun
					outfile.dirname.mkpath
					outfile.open( 'w', 0644 ) do |ofh|
						ofh.print( output )
					end
				else
					$stderr.puts "  would have written %d bytes to %s" %
						[ output.length, outfile ]
				end
			end
		end
	end

end
