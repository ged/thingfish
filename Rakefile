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
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}


require 'thingfish'

require 'rubygems'
require 'rake'
require 'rake/rdoctask'
require 'rake/packagetask'
require 'rake/gempackagetask'
require 'misc/rake/svnhelpers'
require 'pathname'


### Config constants
PKG_NAME      = 'thingfish'
PKG_VERSION   = ThingFish::VERSION
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

BASEDIR       = Pathname.new( __FILE__ ).dirname.expand_path
LIBDIR        = BASEDIR + 'lib'
DOCSDIR       = BASEDIR + 'docs'
MANUALDIR     = DOCSDIR + 'manual'
ARTIFACTS_DIR = Pathname.new( ENV['CC_BUILD_ARTIFACTS'] || '' )

TEXT_FILES    = %w( Rakefile README LICENSE )
SPEC_DIRS     = ['spec'] + Dir.glob( 'plugins/*/spec' )
SPEC_FILES    = Dir.glob( 'spec/*_spec.rb' ) +
                Dir.glob( 'plugins/*/spec/*_spec.rb' )
LIB_FILES     = Dir.glob('lib/**/*.rb').delete_if { |item| item =~ /\.svn/ }

RELEASE_FILES = TEXT_FILES + LIB_FILES + SPEC_FILES




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


### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'docs/html'
	rdoc.title    = "ThingFish - A highly-accessable network datastore"
	rdoc.options += ['-w', '4', '-SHN', '-i', 'docs']

	rdoc.rdoc_files.include TEXT_FILES
	rdoc.rdoc_files.include LIB_FILES
end


### Task: gem
gemspec = Gem::Specification.new do |gem|
	pkg_build = extract_svn_rev( BASEDIR )
	
	gem.name    	= PKG_NAME
	gem.version 	= "%s.%d" % [ PKG_VERSION, pkg_build ]

	gem.summary     = "ThingFish - A highly-accessable network datastore"
	gem.description = <<-EOD
	:TODO: Finish writing this description.
	ThingFish is a highly-accessable network datastore. And it needs more description.
	EOD

	gem.authors  	= "LAIKA, Inc."
	gem.homepage 	= "http://opensource.laika.com"

	gem.has_rdoc 	= true

	gem.files      	= RELEASE_FILES
	gem.test_files 	= SPEC_FILES

	gem.autorequire	= 'thingfish'

  	gem.add_dependency( 'mongrel', '>= 1.0.1' )
  	gem.add_dependency( 'uuidtools', '>= 1.0.0' )
  	gem.add_dependency( 'PluginFactory', '>= 1.0.2' )
end
Rake::GemPackageTask.new( gemspec ) do |task|
	task.gem_spec = gemspec
	task.need_tar = false
	task.need_tar_gz = true
	task.need_tar_bz2 = true
	task.need_zip = true
end


### Task: install
task :install => [:package] do
	installer = Gem::Installer.new( %{pkg/#{PKG_FILE_NAME}.gem} )
	installer.install
end

### Task: uninstall
task :uninstall => [:clean] do
	uninstaller = Gem::Uninstaller.new( PKG_FILE_NAME )
	uninstaller.uninstall
end



### Cruisecontrol task
desc "Cruisecontrol build"
task :cruise => [:clean, :coverage, :package] do |task|
	raise "Artifacts dir not set." if ARTIFACTS_DIR.to_s.empty?
	artifact_dir = ARTIFACTS_DIR.cleanpath
	artifact_dir.mkpath
	
	$deferr.puts "Copying coverage stats..."
	FileUtils.cp_r( 'coverage', artifact_dir )
	
	$deferr.puts "Copying packages..."
	FileUtils.cp_r( FileList['pkg/*'].to_a, artifact_dir )
end



#####################################################################
###	O P T I O N A L   T A S K S
#####################################################################

### Task: install gems for development tasks
DEPENDENCIES = %w[webgen rspec rcov lockfile rcodetools coderay redcloth]
task :install_dependencies do
	# Check for root
	if Process.euid != 0
		$deferr.puts "This probably won't work, as you aren't root, but I'll try anyway"
	end

	installer = Gem::RemoteInstaller.new( :include_dependencies => true )
	gemindex = Gem::SourceIndex.from_installed_gems

	DEPENDENCIES.each do |gemname|
		if (( specs = gemindex.search(gemname) )) && ! specs.empty?
			$deferr.puts "Version %s of %s is already installed; skipping..." % 
				[ specs.first.version, specs.first.name ]
			next
		end

		$deferr.puts "Trying to install #{gemname}..."
		gems = installer.install( gemname )
		gems.compact!
		$deferr.puts "Installed: %s" % [gems.collect {|spec| spec.full_name}.join(', ')]

		gems.each do |gem|
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_ri
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_rdoc
		end
	end
end


### Documentation generation tasks
begin
	gem 'webgen'
	require 'webgen/rake/webgentask'
	gem 'rcodetools'
	gem 'coderay'
	gem 'RedCloth'

	Webgen::Rake::WebgenTask.new( :manual ) do |task|
		task.directory = MANUALDIR
	end
rescue LoadError => err
	task :no_webgen do
		$deferr.puts "Documentation tasks not defined: %s" % [err.message]
	end

	task :manual => :no_webgen
	task :clobber_manual
end




### RSpec tasks
begin
	gem 'rspec', '>= 0.9.4'
	require 'spec/rake/spectask'

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES
		task.libs.unshift( FileList['plugins/**/lib'] )
		task.spec_opts = ['-c', '-f','s', '-b']
	end
	task :test => [:spec] do; end


	### Task: spec:autotest
	namespace :spec do
		desc "Run rspec every time there's a change to one of the files"
		task :autotest do |t|
			basedir = Pathname.new( __FILE__ )
			$LOAD_PATH.unshift( LIBDIR ) unless $LOAD_PATH.include?( LIBDIR )

			require 'rspec_autotest'
			$v = true
			$vcs = 'svn'
			RspecAutotest.run
		end
	
		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.spec_opts = ['-f','s']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$deferr.puts "Testing tasks not defined: RSpec rake tasklib not available: %s" %
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
	gem 'rspec', '>= 0.9.0'
	require 'misc/rake/verifytask'

	### Task: coverage (via RCov)
	desc "Build test coverage reports"
	Spec::Rake::SpecTask.new( :coverage ) do |task|
		task.spec_files = SPEC_FILES
		task.libs += FileList['plugins/**/lib']
		task.rcov_opts = ['--exclude', 'spec', '--xrefs', '--save' ]
		task.rcov = true
	end
	task :rcov => [:coverage] do; end

	### Other coverage tasks
	namespace :coverage do
		desc "Generate a detailed text coverage report"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--exclude', 'spec', '--text-report', '--save']
			task.rcov = true
		end

		desc "Show differences in coverage from last run"
		Spec::Rake::SpecTask.new( :diff ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--exclude', 'spec', '--text-coverage-diff']
			task.rcov = true
		end
	end


	### Task: verify coverage
	desc "Build coverage statistics"
	VerifyTask.new( :verify => :rcov ) do |task|
		task.threshold = 85.0
	end
rescue LoadError => err
	task :no_rcov do
		$deferr.puts "Coverage tasks not defined: RSpec+RCov tasklib not available: %s" %
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


