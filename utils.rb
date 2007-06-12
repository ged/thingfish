#
#	Install/distribution utility functions
#	$Id$
#
#	Copyright (c) 2001-2006, The FaerieMUD Consortium.
#
#	This is free software. You may use, modify, and/or redistribute this
#	software under the terms of the Perl Artistic License. (See
#	http://language.perl.com/misc/Artistic.html)
#

BEGIN {
	require 'rbconfig'
	require 'uri'
	require 'find'
	require 'pp'
	require 'irb'

	begin
		require 'readline'
		include Readline
	rescue LoadError => e
		$stderr.puts "Faking readline..."
		def readline( prompt )
			$stderr.print prompt.chomp
			return $stdin.gets.chomp
		end
	end

}


### Command-line utility functions
module UtilityFunctions
	include Config

	# The list of regexen that eliminate files from the MANIFEST
	ANTIMANIFEST = [
		/makedist\.rb/,
		/\bCVS\b/,
		/~$/,
		/^#/,
		%r{docs/html},
		%r{docs/man},
		/\bTEMPLATE\.\w+\.tpl\b/,
		/\.cvsignore/,
		/\.s?o$/,
	]

	# Set some ANSI escape code constants (Shamelessly stolen from Perl's
	# Term::ANSIColor by Russ Allbery <rra@stanford.edu> and Zenin <zenin@best.com>
	AnsiAttributes = {
		'clear'      => 0,
		'reset'      => 0,
		'bold'       => 1,
		'dark'       => 2,
		'underline'  => 4,
		'underscore' => 4,
		'blink'      => 5,
		'reverse'    => 7,
		'concealed'  => 8,

		'black'      => 30,   'on_black'   => 40, 
		'red'        => 31,   'on_red'     => 41, 
		'green'      => 32,   'on_green'   => 42, 
		'yellow'     => 33,   'on_yellow'  => 43, 
		'blue'       => 34,   'on_blue'    => 44, 
		'magenta'    => 35,   'on_magenta' => 45, 
		'cyan'       => 36,   'on_cyan'    => 46, 
		'white'      => 37,   'on_white'   => 47
	}

	ErasePreviousLine = "\033[A\033[K"

	ManifestHeader = (<<-"EOF").gsub( /^\t+/, '' )
		#
		# Distribution Manifest
		# Created: #{Time::now.to_s}
		# 

	EOF

	###############
	module_function
	###############

	# Create a string that contains the ANSI codes specified and return it
	def ansi_code( *attributes )
		attributes.flatten!
		# $deferr.puts "Returning ansicode for TERM = %p: %p" %
		# 	[ ENV['TERM'], attributes ]
		return '' unless /(?:vt10[03]|xterm(?:-color)?|linux|screen)/i =~ ENV['TERM']
		attributes = AnsiAttributes.values_at( *attributes ).compact.join(';')

		# $deferr.puts "  attr is: %p" % [attributes]
		if attributes.empty? 
			return ''
		else
			return "\e[%sm" % attributes
		end
	end


	### Colorize the given +string+ with the specified +attributes+ and return it, handling line-endings, etc.
	def colorize( string, *attributes )
		ending = string[/(\s)$/] || ''
		string = string.rstrip
		return ansi_code( attributes.flatten ) + string + ansi_code( 'reset' ) + ending
	end


	# Test for the presence of the specified <tt>library</tt>, and output a
	# message describing the test using <tt>nicename</tt>. If <tt>nicename</tt>
	# is <tt>nil</tt>, the value in <tt>library</tt> is used to build a default.
	def test_for_library( library, nicename=nil, progress=false )
		nicename ||= library
		message( "Testing for the #{nicename} library..." ) if progress
		if $LOAD_PATH.detect {|dir|
				File.exists?(File.join(dir,"#{library}.rb")) ||
				File.exists?(File.join(dir,"#{library}.#{CONFIG['DLEXT']}"))
			}
			message( "found.\n" ) if progress
			return true
		else
			message( "not found.\n" ) if progress
			return false
		end
	end

	# Test for the presence of the specified <tt>library</tt>, and output a
	# message describing the problem using <tt>nicename</tt>. If
	# <tt>nicename</tt> is <tt>nil</tt>, the value in <tt>library</tt> is used
	# to build a default. If <tt>raaUrl</tt> and/or <tt>downloadUrl</tt> are
	# specified, they are also use to build a message describing how to find the
	# required library. If <tt>fatal</tt> is <tt>true</tt>, a missing library
	# will cause the program to abort.
	def test_for_required_library( library, nicename=nil, raaUrl=nil, downloadUrl=nil, fatal=true )
		nicename ||= library
		unless test_for_library( library, nicename )
			msgs = [ "You are missing the required #{nicename} library.\n" ]
			msgs << "RAA: #{raaUrl}\n" if raaUrl
			msgs << "Download: #{downloadUrl}\n" if downloadUrl
			if fatal
				abort msgs.join('')
			else
				error_message msgs.join('')
			end
		end
		return true
	end

	### Output <tt>msg</tt> as a ANSI-colored program/section header (white on
	### blue).
	def header( msg )
		msg.chomp!
		$stderr.puts ansi_code( 'bold', 'white', 'on_blue' ) + msg + ansi_code( 'reset' )
		$stderr.flush
	end

	### Output <tt>msg</tt> to STDERR and flush it.
	def message( *msgs )
		$stderr.print( msgs.join("\n") )
		$stderr.flush
	end

	### Output +msg+ to STDERR and flush it if $VERBOSE is true.
	def verbose_msg( msg )
		msg.chomp!
		message( msg + "\n" ) if $VERBOSE
	end

	### Output the specified <tt>msg</tt> as an ANSI-colored error message
	### (white on red).
	def error_msg( msg )
		message ansi_code( 'bold', 'white', 'on_red' ) + msg + ansi_code( 'reset' )
	end
	alias :error_message :error_msg

	### Output the specified <tt>msg</tt> as an ANSI-colored debugging message
	### (yellow on blue).
	def debug_msg( msg )
		return unless $DEBUG
		msg.chomp!
		$stderr.puts ansi_code( 'bold', 'yellow', 'on_blue' ) + ">>> #{msg}" + ansi_code( 'reset' )
		$stderr.flush
	end

	### Erase the previous line (if supported by your terminal) and output the
	### specified <tt>msg</tt> instead.
	def replace_msg( msg )
		$stderr.puts
		$stderr.print ErasePreviousLine
		message( msg )
	end
	alias :replace_message :replace_msg

	### Output a divider made up of <tt>length</tt> hyphen characters.
	def divider( length=75 )
		$stderr.puts "\r" + ("-" * length )
	end
	alias :writeLine :divider


	### Output the specified <tt>msg</tt> colored in ANSI red and exit with a
	### status of 1.
	def abort( msg )
		print ansi_code( 'bold', 'red' ) + "Aborted: " + msg.chomp + ansi_code( 'reset' ) + "\n\n"
		Kernel.exit!( 1 )
	end


	### Output the specified <tt>prompt_string</tt> as a prompt (in green) and
	### return the user's input with leading and trailing spaces removed.  If a
	### test is provided, the prompt will repeat until the test returns true.
	### An optional failure message can also be passed in.
	def prompt( prompt_string, failure_msg="Try again." ) # :yields: response
		prompt_string.chomp!
		prompt_string << ":" unless /\W$/.match( prompt_string )
		response = nil

		begin
			response = readline( ansi_code('bold', 'green') +
				"#{prompt_string} " + ansi_code('reset') ) || ''
			response.strip!
			if block_given? && ! yield( response ) 
				error_message( failure_msg + "\n\n" )
				response = nil
			end
		end until response

		return response
	end


	### Prompt the user with the given <tt>prompt_string</tt> via #prompt,
	### substituting the given <tt>default</tt> if the user doesn't input
	### anything.  If a test is provided, the prompt will repeat until the test
	### returns true.  An optional failure message can also be passed in.
	def prompt_with_default( prompt_string, default, failure_msg="Try again." )
		response = nil

		begin
			response = prompt( "%s [%s]" % [ prompt_string, default ] )
			response = default if response.empty?

			if block_given? && ! yield( response ) 
				error_message( failure_msg + "\n\n" )
				response = nil
			end
		end until response

		return response
	end


	$programs = {}

	### Search for the program specified by the given <tt>progname</tt> in the
	### user's <tt>PATH</tt>, and return the full path to it, or <tt>nil</tt> if
	### no such program is in the path.
	def find_program( progname )
		unless $programs.key?( progname )
			ENV['PATH'].split(File::PATH_SEPARATOR).each {|d|
				file = File.join( d, progname )
				if File.executable?( file )
					$programs[ progname ] = file 
					break
				end
			}
		end

		return $programs[ progname ]
	end


	### Search for the release version for the project in the specified
	### +directory+.
	def extract_version( directory='.' )
		release = nil

		Dir::chdir( directory ) do
			if File::directory?( "CVS" )
				verbose_msg( "Project is versioned via CVS. Searching for RELEASE_*_* tags..." )

				if (( cvs = find_program('cvs') ))
					revs = []
					output = %x{cvs log}
					output.scan( /RELEASE_(\d+(?:_\d\w+)*)/ ) {|match|
						rev = $1.split(/_/).collect {|s| Integer(s) rescue 0}
						verbose_msg( "Found %s...\n" % rev.join('.') )
						revs << rev
					}

					release = revs.sort.last
				end

			elsif File::directory?( '.svn' )
				verbose_msg( "Project is versioned via Subversion" )

				if (( svn = find_program('svn') ))
					output = %x{svn pg project-version}.chomp
					unless output.empty?
						verbose_msg( "Using 'project-version' property: %p" % output )
						release = output.split( /[._]/ ).collect {|s| Integer(s) rescue 0}
					end
				end
			end
		end

		return release
	end


	### Find the current release version for the project in the specified
	### +directory+ and return its successor.
	def extract_next_version( directory='.' )
		version = extract_version( directory ) || [0,0,0]
		version.compact!
		version[-1] += 1

		return version
	end


	# Pattern for extracting the name of the project from a Subversion URL
	SVNUrlPath = %r{
		.*/						# Skip all but the last bit
		([^/]+)					# $1 = project name
		/						# Followed by / +
		(?:
			trunk |				# 'trunk'
			(
				branches |		# ...or branches/branch-name
				tags			# ...or tags/tag-name
			)/\w	
		)
		$						# bound to the end
	}ix

	### Extract the project name (CVS Repository name) for the given +directory+.
	def extract_project_name( directory='.' )
		name = nil

		Dir::chdir( directory ) do

			# CVS-controlled
			if File::directory?( "CVS" )
				verbose_msg( "Project is versioned via CVS. Using repository name." )
				name = File.open( "CVS/Repository", "r").readline.chomp
				name.sub!( %r{.*/}, '' )

			# Subversion-controlled
			elsif File::directory?( '.svn' )
				verbose_msg( "Project is versioned via Subversion" )

				# If the machine has the svn tool, try to get the project name
				if (( svn = find_program( 'svn' ) ))

					# First try an explicit property
					output = shell_command( svn, 'pg', 'project-name' )
					if !output.empty?
						verbose_msg( "Using 'project-name' property: %p" % output )
						name = output.first.chomp

					# If that doesn't work, try to figure it out from the URL
					elsif (( uri = get_svn_uri() ))
						name = uri.path.sub( SVNUrlPath ) { $1 }
					end
				end
			end

			# Fall back to guessing based on the directory name
			unless name
				name = File::basename(File::dirname( File::expand_path(__FILE__) ))
			end
		end

		return name
	end


	### Extract the Subversion URL from the specified directory and return it as
	### a URI object.
	def get_svn_uri( directory='.' )
		uri = nil

		Dir::chdir( directory ) do
			output = %x{svn info}
			debug_msg( "Using info: %p" % output )

			if /^URL: \s* ( .* )/xi.match( output )
				uri = URI::parse( $1 )
			end
		end

		return uri
	end


	### (Re)make a manifest file in the specified +path+.
	def make_manifest( path="MANIFEST" )
		if File::exists?( path )
			reply = prompt_with_default( "Replace current '#{path}'? [yN]", "n" )
			return false unless /^y/i.match( reply )

			verbose_msg "Replacing manifest at '#{path}'"
		else
			verbose_msg "Creating new manifest at '#{path}'"
		end

		files = []
		verbose_msg( "Finding files...\n" )
		Find::find( Dir::pwd ) do |f|
			Find::prune if File::directory?( f ) &&
				/^\./.match( File::basename(f) )
			verbose_msg( "  found: #{f}\n" )
			files << f.sub( %r{^#{Dir::pwd}/?}, '' )
		end
		files = vet_manifest( files )

		verbose_msg( "Writing new manifest to #{path}..." )
		File::open( path, File::WRONLY|File::CREAT|File::TRUNC ) do |ofh|
			ofh.puts( ManifestHeader )
			ofh.puts( files )
		end
		verbose_msg( "done." )
	end


	### Read the specified <tt>manifestFile</tt>, which is a text file
	### describing which files to package up for a distribution. The manifest
	### should consist of one or more lines, each containing one filename or
	### shell glob pattern.
	def read_manifest( manifestFile="MANIFEST" )
		verbose_msg "Building manifest..."
		raise "Missing #{manifestFile}, please remake it" unless File.exists? manifestFile

		manifest = IO::readlines( manifestFile ).collect {|line|
			line.chomp
		}.select {|line|
			line !~ /^(\s*(#.*)?)?$/
		}

		filelist = []
		for pat in manifest
			verbose_msg "Adding files that match '#{pat}' to the file list"
			filelist |= Dir.glob( pat ).find_all {|f| FileTest.file?(f)}
		end

		verbose_msg "found #{filelist.length} files.\n"
		return filelist
	end


	### Given a <tt>filelist</tt> like that returned by #read_manifest, remove
	### the entries therein which match the Regexp objects in the given
	### <tt>antimanifest</tt> and return the resultant Array.
	def vet_manifest( filelist, antimanifest=ANTIMANIFEST )
		origLength = filelist.length
		verbose_msg "Vetting manifest..."

		for regex in antimanifest
			verbose_msg "\n\tPattern /#{regex.source}/ removed: " +
				filelist.find_all {|file| regex.match(file)}.join(', ')
			filelist.delete_if {|file| regex.match(file)}
		end

		verbose_msg "removed #{origLength - filelist.length} files from the list.\n"
		return filelist
	end


	### Combine a call to #read_manifest with one to #vet_manifest.
	def get_vetted_manifest( manifestFile="MANIFEST", antimanifest=ANTIMANIFEST )
		vet_manifest( read_manifest(manifestFile), antimanifest )
	end


	### Given a documentation <tt>catalogFile</tt>, extract the title, if
	### available, and return it. Otherwise generate a title from the name of
	### the CVS module.
	def find_rdoc_title( catalogFile="docs/CATALOG" )

		# Try extracting it from the CATALOG file from a line that looks like:
		# Title: Foo Bar Module
		title = find_catalog_keyword( 'title', catalogFile )

		# If that doesn't work for some reason, use the name of the project.
		title = extract_project_name()

		return title
	end


	### Given a documentation <tt>catalogFile</tt>, extract the name of the file
	### to use as the initally displayed page. If extraction fails, the
	### +default+ will be used if it exists. Returns +nil+ if there is no main
	### file to be found.
	def find_rdoc_main( catalogFile="docs/CATALOG", default="README" )

		# Try extracting it from the CATALOG file from a line that looks like:
		# Main: Foo Bar Module
		main = find_catalog_keyword( 'main', catalogFile )

		# Try to make some educated guesses if that doesn't work
		if main.nil?
			basedir = File::dirname( __FILE__ )
			basedir = File::dirname( basedir ) if /docs$/ =~ basedir

			if File::exists?( File::join(basedir, default) )
				main = default
			end
		end

		return main
	end


	### Given a documentation <tt>catalogFile</tt>, extract an upload URL for
	### RDoc.
	def find_rdoc_upload( catalogFile="docs/CATALOG" )
		find_catalog_keyword( 'upload', catalogFile )
	end


	### Given a documentation <tt>catalogFile</tt>, extract a CVS web frontend
	### URL for RDoc.
	def find_rdoc_cvs_url( catalogFile="docs/CATALOG" )
		find_catalog_keyword( 'webcvs', catalogFile )
	end


	### Find one or more 'accessor' directives in the catalog if they exist and
	### return an Array of them.
	def find_rdoc_accessors( catalogFile="docs/CATALOG" )
		accessors = []
		in_attr_section = false
		indent = ''

		if File::exists?( catalogFile )
			verbose_msg "Extracting accessors from CATALOG file (%s).\n" % catalogFile

			# Read lines from the catalog
			File::foreach( catalogFile ) do |line|
				debug_msg( "  Examining line #{line.inspect}..." )

				# Multi-line accessors
				if in_attr_section
					if /^#\s+([a-z0-9_]+(?:\s*=\s*.*)?)$/i.match( line )
						debug_msg( "    Found accessor: #$1" )
						accessors << $1
						next
					end

					debug_msg( "  End of accessors section." )
					in_attr_section = false

				# Single-line accessor
				elsif /^#\s*Accessors:\s*(\S+)$/i.match( line )
					debug_msg( "  Found single accessors line: #$1" )
					vals = $1.split(/,/).collect {|val| val.strip }
					accessors.replace( vals )

				# Multi-line accessor header
				elsif /^#\s*Accessors:\s*$/i.match( line )
					debug_msg( "  Start of accessors section." )
					in_attr_section = true
				end

			end
		end

		debug_msg( "Found accessors: %s" % accessors.join(",") )
		return accessors
	end


	### Given a documentation <tt>catalogFile</tt>, try extracting the given
	### +keyword+'s value from it. Keywords are lines that look like:
	###   # <keyword>: <value>
	### Returns +nil+ if the catalog file was unreadable or didn't contain the
	### specified +keyword+.
	def find_catalog_keyword( keyword, catalogFile="docs/CATALOG" )
		val = nil

		if File::exists? catalogFile
			verbose_msg "Extracting '#{keyword}' from CATALOG file (%s).\n" % catalogFile
			File::foreach( catalogFile ) do |line|
				debug_msg( "Examining line #{line.inspect}..." )
				val = $1.strip and break if /^#\s*#{keyword}:\s*(.*)$/i.match( line )
			end
		end

		return val
	end


	### Given a documentation <tt>catalogFile</tt>, which is in the same format
	### as that described by #read_manifest, read and expand it, and then return
	### a list of those files which appear to have RDoc documentation in
	### them. If <tt>catalogFile</tt> is nil or does not exist, the MANIFEST
	### file is used instead.
	def find_rdocable_files( catalogFile="docs/CATALOG" )
		startlist = []
		if File.exists? catalogFile
			verbose_msg "Using CATALOG file (%s).\n" % catalogFile
			startlist = get_vetted_manifest( catalogFile )
		else
			verbose_msg "Using default MANIFEST\n"
			startlist = get_vetted_manifest()
		end

		verbose_msg "Looking for RDoc comments in:\n"
		startlist.select {|fn|
			verbose_msg "  #{fn}: "
			found = false
			File::open( fn, "r" ) {|fh|
				fh.each {|line|
					if line =~ /^(\s*#)?\s*=/ || line =~ /:\w+:/ || line =~ %r{/\*}
						found = true
						break
					end
				}
			}

			verbose_msg( (found ? "yes" : "no") + "\n" )
			found
		}
	end


	### Open a file and filter each of its lines through the given block a
	### <tt>line</tt> at a time. The return value of the block is used as the
	### new line, or omitted if the block returns <tt>nil</tt> or
	### <tt>false</tt>.
	def edit_in_place( file, testMode=false ) # :yields: line
		raise "No block specified for editing operation" unless block_given?

		tempName = "#{file}.#{$$}"
		File::open( tempName, File::RDWR|File::CREAT, 0600 ) {|tempfile|
			File::open( file, File::RDONLY ) {|fh|
				fh.each {|line|
					newline = yield( line ) or next
					tempfile.print( newline )
					$deferr.puts "%p -> %p" % [ line, newline ] if
						line != newline
				}
			}
		}

		if testMode
			File::unlink( tempName )
		else
			File::rename( tempName, file )
		end
	end


	### Execute the specified shell <tt>command</tt>, read the results, and
	### return them. Like a %x{} that returns an Array instead of a String.
	def shell_command( *command )
		raise "Empty command" if command.empty?

		cmdpipe = IO::popen( command.join(' '), 'r' )
		return cmdpipe.readlines
	end


	### Execute a block with $VERBOSE set to +false+, restoring it to its
	### previous value before returning.
	def verbose_off
		raise LocalJumpError, "No block given" unless block_given?

		thrcrit = Thread.critical
		oldverbose = $VERBOSE
		begin
			Thread.critical = true
			$VERBOSE = false
			yield
		ensure
			$VERBOSE = oldverbose
			Thread.critical = false
		end
	end


	### Try the specified code block, printing the given 
	def try( msg, bind=TOPLEVEL_BINDING )
		result = ''
		if msg =~ /^to\s/
			message "Trying #{msg}...\n"
		else
			message msg + "\n"
		end

		begin
			rval = nil
			if block_given?
				rval = yield
			else
				file, line = caller(1)[0].split(/:/,2)
				rval = eval( msg, bind, file, line.to_i )
			end

			PP.pp( rval, result )

		rescue Exception => err
			if err.backtrace
				nicetrace = err.backtrace.delete_if {|frame|
					/in `(try|eval)'/ =~ frame
				}.join("\n\t")
			else
				nicetrace = "Exception had no backtrace"
			end

			result = err.message + "\n\t" + nicetrace

		ensure
			divider
			message result.chomp + "\n"
			divider
			$deferr.puts
		end
	end


	### Start an IRB session with the specified binding +b+ as the current scope.
	def start_irb_session( b )
		IRB.setup(nil)

		workspace = IRB::WorkSpace.new( b )

		if IRB.conf[:SCRIPT]
			irb = IRB::Irb.new( workspace, IRB.conf[:SCRIPT] )
		else
			irb = IRB::Irb.new( workspace )
		end

		IRB.conf[:IRB_RC].call( irb.context ) if IRB.conf[:IRB_RC]
		IRB.conf[:MAIN_CONTEXT] = irb.context

		trap("SIGINT") do
			irb.signal_handle
		end

		catch(:IRB_EXIT) do
			irb.eval_input
		end
	end

end # module UtilityFunctions



if __FILE__ == $0
	# $DEBUG = true
	include UtilityFunctions

	projname = extract_project_name()
	header "Project: #{projname}"

	ver = extract_version() || [0,0,1]
	puts "Version: %s\n" % ver.join('.')

	if File::directory?( "docs" )
		puts "Rdoc:",
			"  Title: " + find_rdoc_title(),
			"  Main: " + find_rdoc_main(),
			"  Upload: " + find_rdoc_upload(),
			"  SCCS URL: " + find_rdoc_cvs_url(),
			"  Accessors: " + find_rdoc_accessors().join(",")
	end

	puts "Manifest:",
		"  " + get_vetted_manifest().join("\n  ")
end