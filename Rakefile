#!rake
#
# ThingFish rakefile
#
# Based on Ben Bleything's Rakefile for Linen (URL?)
#
# Copyright (c) 2007 LAIKA, Inc.
#
# Mistakes:
#  * Michael Granger <mgranger@laika.com>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname
	libdir = basedir + 'lib'
	docsdir = basedir + 'docs'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	$LOAD_PATH.unshift( docsdir.to_s ) unless $LOAD_PATH.include?( docsdir.to_s )
}


require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'pathname'

$dryrun = false

# Pathname constants
BASEDIR       = Pathname.new( __FILE__ ).dirname.expand_path
LIBDIR        = BASEDIR + 'lib'
DOCSDIR       = BASEDIR + 'docs'
VARDIR        = BASEDIR + 'var'
MISCDIR       = BASEDIR + 'misc'
WWWDIR        = VARDIR  + 'www'
MANUALDIR     = DOCSDIR + 'manual'
RDOCDIR       = DOCSDIR + 'rdoc'
STATICWWWDIR  = WWWDIR  + 'static'
PKGDIR        = BASEDIR + 'pkg'
ARTIFACTS_DIR = Pathname.new( ENV['CC_BUILD_ARTIFACTS'] || '' )

TEXT_FILES    = %w( Rakefile README LICENSE ).
	collect {|filename| BASEDIR + filename }

SPECDIR       = BASEDIR + 'spec'
SPEC_FILES    = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }
SPEC_EXCLUDES = 'spec,monkeypatches,/Library/Ruby'

LIB_FILES     = Pathname.glob( LIBDIR + '**/*.rb').
	delete_if {|item| item =~ /\.svn/ }

RELEASE_FILES = TEXT_FILES + LIB_FILES + SPEC_FILES

# Plugin constants
PLUGINDIR        = BASEDIR + 'plugins'
PLUGINS          = Pathname.glob( PLUGINDIR + '*' ).select {|path| path.directory? }
PLUGIN_LIBS      = PLUGINS.collect {|dir| Pathname.glob(dir + 'lib/**/*.rb') }.flatten
PLUGIN_RAKEFILES = PLUGINS.collect {|dir| dir + 'Rakefile' }
PLUGIN_SPECFILES = PLUGINS.collect {|dir| Pathname.glob(dir + 'spec/*_spec.rb') }.flatten

require MISCDIR + 'rake/helpers'

### Package constants
PKG_NAME      = 'thingfish'
PKG_VERSION   = find_pattern_in_file( /VERSION = '(\d+\.\d+\.\d+)'/, LIBDIR + 'thingfish.rb' ).first
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

# Load task plugins
RAKE_TASKDIR = MISCDIR + 'rake'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	next if tasklib =~ %r{/helpers.rb$}
	require tasklib
end

if Rake.application.options.trace
	$trace = true
	log "$trace is enabled"
end

if Rake.application.options.dryrun
	$dryrun = true
	log "$dryrun is enabled"
	Rake.application.options.dryrun = false
end

### Default task
task :default  => [:clean, :spec, :verify, :package]


### Task: clean
desc "Clean pkg, coverage, and rdoc; remove .bak files"
task :clean => [ :clobber_rdoc, :clobber_package, :clobber_coverage, :clobber_manual ] do
	files = FileList['**/*.bak']
	files.clear_exclude
	File.rm( files ) unless files.empty?
	FileUtils.rm_rf( 'artifacts' )
end


### Task: docs -- Convenience task for rebuilding dynamic docs, including coverage, api 
### docs, and manual
task :docs => [ :manual, :coverage, :rdoc ]


### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'docs/api'
	rdoc.title    = "ThingFish - A highly-accessable network datastore"

	rdoc.options += [
		'-w', '4',
		'-SHN',
		'-i', 'docs',
		'-f', 'darkfish',
		'-m', 'README',
		'-W', 'http://opensource.laika.com/browser/thingfish/trunk/'
	  ]
	
	rdoc.rdoc_files.include 'README'
	rdoc.rdoc_files.include LIB_FILES.collect {|f| f.relative_path_from(BASEDIR).to_s }
end
task :rdoc do
	outputdir = DOCSDIR + 'api'
	targetdir = STATICWWWDIR + 'api'

	rmtree( targetdir )
	cp_r( outputdir, targetdir, :verbose => true )
end
task :clobber_rdoc do
	rmtree( STATICWWWDIR + 'api', :verbose => true )
end


### Task: gem
gemspec = Gem::Specification.new do |gem|
	pkg_build = get_svn_rev( BASEDIR ) || 0
	
	gem.name    	= PKG_NAME
	gem.version 	= "%s.%s" % [ PKG_VERSION, pkg_build ]

	gem.summary     = "ThingFish - A highly-accessable network datastore"
	gem.description = <<-EOD
	:TODO: Finish writing this description.
	ThingFish is a highly-accessable network datastore. And it needs more description.
	EOD

	gem.authors  	= "LAIKA, Inc."
	gem.homepage 	= "http://opensource.laika.com"

	gem.has_rdoc 	= true

	gem.files      	= RELEASE_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }
	gem.test_files 	= SPEC_FILES.
		collect {|f| f.relative_path_from(BASEDIR).to_s }

	gem.autorequire	= 'thingfish'

  	gem.add_dependency( 'mongrel', '>= 1.0.1' )
  	gem.add_dependency( 'uuidtools', '>= 1.0.0' )
  	gem.add_dependency( 'pluginfactory	', '>= 1.0.3' )
end
Rake::GemPackageTask.new( gemspec ) do |task|
	task.gem_spec = gemspec
	task.need_tar = false
	task.need_tar_gz = true
	task.need_tar_bz2 = true
	task.need_zip = true
end


desc "Build the ThingFish gem and gems for all the standard plugins"
task :gems => [:gem] do
	log "Building gems for plugins in: %s" % [PLUGINS.join(', ')]
	PLUGINS.each do |plugindir|
		cp BASEDIR + 'LICENSE', plugindir
		Dir.chdir( plugindir ) do
			system 'rake', 'gem'
		end
		
		fail unless $?.success?
		
		pkgdir = plugindir + 'pkg'
		gems = Pathname.glob( pkgdir + '*.gem' )
		log "Would copy #{gems} from #{pkgdir} to #{PKGDIR}"
		cp gems, PKGDIR
	end
end


### Task: install
task :install_gem => [:package] do
	$stderr.puts 
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall
task :uninstall_gem => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end



### Cruisecontrol task
desc "Cruisecontrol build"
task :cruise => [:clean, :coverage, :package] do |task|
	raise "Artifacts dir not set." if ARTIFACTS_DIR.to_s.empty?
	artifact_dir = ARTIFACTS_DIR.cleanpath
	artifact_dir.mkpath
	
	$stderr.puts "Copying coverage stats..."
	FileUtils.cp_r( 'coverage', artifact_dir )
	
	$stderr.puts "Copying packages..."
	FileUtils.cp_r( FileList['pkg/*'].to_a, artifact_dir )
end



#####################################################################
###	O P T I O N A L   T A S K S
#####################################################################

require 'rubygems/installer'
require 'rubygems/remote_installer'
require 'rubygems/doc_manager'

class Gem::RemoteInstaller

	def install( gem_name, version_requirement=Gem::Requirement.default, force=false, install_dir=Gem.dir )
		unless version_requirement.respond_to?(:satisfied_by?)
			version_requirement = Gem::Requirement.new [version_requirement]
		end
		installed_gems = []
		begin
			spec, source = find_gem_to_install(gem_name, version_requirement)
			dependencies = find_dependencies_not_installed(spec.dependencies)

			installed_gems << install_dependencies(dependencies, force, install_dir)

			cache_dir = @options[:cache_dir] || File.join(install_dir, "cache")
			destination_file = File.join( cache_dir, spec.full_name + ".gem" )

			download_gem( destination_file, source, spec )

			installer = new_installer( destination_file )
			installed_gems.unshift( installer.install )
		rescue Gem::RemoteInstallationSkipped => e
			alert_error e.message
		end
		return installed_gems.flatten
	end

end

### Attempt to install the given +gemlist+.
def install_gems( gemlist )
	# Check for root
	unless Process.euid.zero?
		$stderr.puts "This probably won't work, as you aren't root, but I'll try anyway"
	end

	installer = Gem::RemoteInstaller.new( :include_dependencies => true )
	gemindex = Gem::SourceIndex.from_installed_gems

	gemlist.each do |gemname|
		if (( specs = gemindex.search(gemname) )) && ! specs.empty?
			$stderr.puts "Version %s of %s is already installed; skipping..." % 
				[ specs.first.version, specs.first.name ]
			next
		end

		$stderr.puts "Trying to install #{gemname}..."
		gems = installer.install( gemname )
		gems.compact!
		$stderr.puts "Installed: %s" % [gems.collect {|spec| spec.full_name}.join(', ')]

		gems.each do |gem|
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_ri
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_rdoc
		end
	end
end


### Task: install gems for development tasks
DEPENDENCIES = %w[pluginfactory mongrel rcov uuidtools webgen rspec rcov lockfile rcodetools coderay redcloth]
task :install_dependencies do
	install_gems( DEPENDENCIES )
end

### Task: install gems for all plugins
PLUGIN_DEPENDENCIES = %w[sqlite3-ruby exifr RMagick json ruby-mp3info tidy]
task :install_plugin_dependencies do
	install_gems( PLUGIN_DEPENDENCIES )
end


### Documentation generation tasks
begin
	gem 'webgen'
	require 'webgen/website'
	gem 'rcodetools', '>= 0.7.0.0'
	gem 'coderay'
	gem 'RedCloth'

	OUTPUTDIR = MANUALDIR + 'output'
	TARGETDIR = STATICWWWDIR + 'manual'

	desc "Generate the manual with webgen"
	task :manual do |task|

		Dir.chdir( MANUALDIR ) do
			log "Building the manual"
			
			config_file = Webgen::WebSite.load_config_file( MANUALDIR + 'src' )
			website = Webgen::WebSite.new( MANUALDIR )
			website.render

			log "Webgen rendered to: #{OUTPUTDIR}"
		end

		rmtree( TARGETDIR )
		cp_r( OUTPUTDIR, TARGETDIR, :verbose => true )
	end
	
	task :clobber_manual do
		rm_rf( OUTPUTDIR, :verbose => true )
		rm_rf( TARGETDIR, :verbose => true )
	end
	
rescue LoadError => err
	task :no_webgen do
		$stderr.puts "Documentation tasks not defined: %s" % [err.message]
	end

	task :manual => :no_webgen
	task :clobber_manual
end




### RSpec tasks
begin
	gem 'rspec', '>= 1.1.1'
	require 'spec/rake/spectask'

	COMMON_SPEC_OPTS = ['-c', '-f', 's']

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
		task.libs += [LIBDIR]
		task.spec_opts = COMMON_SPEC_OPTS
	end
	task :test => [:spec]


	namespace :spec do
		desc "Run specs for the included plugins"
		Spec::Rake::SpecTask.new( :plugins ) do |task|
			task.spec_files = PLUGIN_SPECFILES
			task.libs += [LIBDIR] + PLUGIN_LIBS
			task.spec_opts = COMMON_SPEC_OPTS
		end

		desc "Run rspec every time there's a change to one of the files"
        task :autotest do
            require 'autotest/rspec'

			### Mmmm... smells like monkeys
			class Autotest::Rspec

				### Search the path for 'spec' in addition to the simple included methods
				### for finding it.
				def spec_commands
					path = ENV['PATH'].split( File::PATH_SEPARATOR )
					return path.collect {|dir| File.join(dir, 'spec') } +
					[
						File.join('bin', 'spec'),
						File.join(Config::CONFIG['bindir'], 'spec')
					]
				end

			end

            autotester = Autotest::Rspec.new

			autotester.exceptions = %r{\.svn|\.skel}
            autotester.test_mappings = {
                %r{^spec/.*\.rb$} => proc {|filename, _|
                    filename
                },
                %r{^lib/thingfish/([^/]*)\.rb$} => proc {|_, m|
                    ["spec/#{m[1]}_spec.rb"]
                },
                %r{^lib/thingfish/(.*)/(.*)\.rb$} => proc {|_, m|
                    ["spec/#{m[2] + m[1]}_spec.rb", "spec/#{m[1]}/#{m[2]}_spec.rb"]
                },
                %r{^plugins/(.*?)/.*\.rb$} => proc {|_, m|
                    autotester.files_matching %r{plugins/#{m[1]}/spec/.*_spec.rb}
                },
                %r{^spec/lib/(.*)_behavior\.rb$} => proc {|_, m|
                    autotester.files_matching %r{^.*#{m[0]}_spec\.rb$}
                },
            }
            
            autotester.run
        end

	
		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
			task.spec_opts = ['-f','p']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$stderr.puts "Testing tasks not defined: RSpec rake tasklib not available: %s" %
			[ err.message ]
	end
	
	task :spec => :no_rspec
	namespace :spec do
		task :autotest => :no_rspec
		task :html => :no_rspec
		task :text => :no_rspec
	end
end


### RCov (via RSpec) tasks
begin
	gem 'rcov'
	gem 'rspec', '>= 1.1.1'

	COVERAGE_TARGETDIR = STATICWWWDIR + 'coverage'

	RCOV_OPTS = ['--exclude', SPEC_EXCLUDES, '--xrefs', '--save']

	### Task: coverage (via RCov)
	### Task: spec
	desc "Build test coverage reports"
	Spec::Rake::SpecTask.new( :coverage ) do |task|
		task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
		task.libs += [LIBDIR] + PLUGIN_LIBS
		task.spec_opts = ['-f', 'p', '-b']
		task.rcov_opts = RCOV_OPTS
		task.rcov = true
	end
	task :coverage do
		rmtree( COVERAGE_TARGETDIR )
		cp_r( 'coverage', COVERAGE_TARGETDIR, :verbose => true )
	end
	
	task :rcov => [:coverage] do; end
	
	### Other coverage tasks
	namespace :coverage do
		desc "Generate a detailed text coverage report"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = RCOV_OPTS + ['--text-report']
			task.rcov = true
		end

		desc "Show differences in coverage from last run"
		Spec::Rake::SpecTask.new( :diff ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--text-coverage-diff']
			task.rcov = true
		end

		### Task: verify coverage
		desc "Build coverage statistics"
		VerifyTask.new( :verify => :rcov ) do |task|
			task.threshold = 85.0
		end
		
		desc "Run RCov in 'spec-only' mode to check coverage from specs"
		Spec::Rake::SpecTask.new( :speconly ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--exclude', SPEC_EXCLUDES, '--text-report', '--save']
			task.rcov = true
		end
	end

	task :clobber_coverage do
		rmtree( COVERAGE_TARGETDIR )
	end

rescue LoadError => err
	task :no_rcov do
		$stderr.puts "Coverage tasks not defined: RSpec+RCov tasklib not available: %s" %
			[ err.message ]
	end

	task :coverage => :no_rcov
	task :clobber_coverage
	task :rcov => :no_rcov
	namespace :coverage do
		task :text => :no_rcov
		task :diff => :no_rcov
	end
	task :verify => :no_rcov
end



### Coding style checks and fixes
namespace :style do
	
	BLANK_LINE = /^\s*$/
	GOOD_INDENT = /^(\t\s*)?\S/

	# A list of the files that have legitimate leading whitespace, etc.
	PROBLEM_FILES = [ SPECDIR + 'config_spec.rb' ]
	
	desc "Check source files for inconsistent indent and fix them"
	task :fix_indent do
		files = LIB_FILES +
			SPEC_FILES +
			PLUGIN_LIBS +
			PLUGIN_SPECFILES

		badfiles = Hash.new {|h,k| h[k] = [] }
		
		trace "Checking files for indentation"
		files.each do |file|
			if PROBLEM_FILES.include?( file )
				trace "  skipping problem file #{file}..."
				next
			end
			
			trace "  #{file}"
			linecount = 0
			file.each_line do |line|
				linecount += 1
				
				# Skip blank lines
				next if line =~ BLANK_LINE
				
				# If there's a line with incorrect indent, note it and skip to the 
				# next file
				if line !~ GOOD_INDENT
					trace "    Bad line %d: %p" % [ linecount, line ]
					badfiles[file] << [ linecount, line ]
				end
			end
		end

		if badfiles.empty?
			log "No indentation problems found."
		else
			log "Found incorrect indent in #{badfiles.length} files:\n  "
			badfiles.each do |file, badlines|
				log "  #{file}:\n" +
					"    " + badlines.collect {|badline| "%5d: %p" % badline }.join( "\n    " )
			end
		end
	end

end


