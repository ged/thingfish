#!rake -*- ruby -*-
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
require 'tmpdir'
require 'pathname'

$dryrun = false

# Pathname constants
BASEDIR         = Pathname.new( __FILE__ ).expand_path.dirname.relative_path_from( Pathname.getwd )
BINDIR          = BASEDIR + 'bin'
LIBDIR          = BASEDIR + 'lib'
DOCSDIR         = BASEDIR + 'docs'
VARDIR          = BASEDIR + 'var'
MISCDIR         = BASEDIR + 'misc'
WWWDIR          = VARDIR  + 'www'
STATICWWWDIR    = WWWDIR  + 'static'
MANUALDIR       = DOCSDIR + 'manual'
MANUALOUTPUTDIR = STATICWWWDIR    + 'manual'
RDOCDIR         = MANUALOUTPUTDIR + 'api'
PKGDIR          = BASEDIR + 'pkg'
ARTIFACTS_DIR   = Pathname.new( ENV['CC_BUILD_ARTIFACTS'] || '' )
RAKE_TASKDIR    = MISCDIR + 'rake'

TEXT_FILES    = %w( Rakefile README LICENSE QUICKSTART ).
	collect {|filename| BASEDIR + filename }

SPECDIR       = BASEDIR + 'spec'
SPEC_FILES    = Pathname.glob( SPECDIR + '**/*_spec.rb' ).
	delete_if {|item| item =~ /\.svn/ }
# Ideally, this should be automatically generated.
SPEC_EXCLUDES = 'spec,monkeypatches,/Library/Ruby,/var/lib,/usr/local/lib'

BIN_FILES     = Pathname.glob( BINDIR + '*').
	delete_if {|item| item =~ /\.svn/ }
LIB_FILES     = Pathname.glob( LIBDIR + '**/*.rb').
	delete_if {|item| item =~ /\.svn/ }

RELEASE_FILES = BIN_FILES + TEXT_FILES + LIB_FILES + SPEC_FILES

# Plugin constants
PLUGINDIR        = BASEDIR + 'plugins'
PLUGINS          = Pathname.glob( PLUGINDIR + '*' ).select {|path| path.directory? }
PLUGIN_LIBS      = PLUGINS.collect {|dir| Pathname.glob(dir + 'lib/**/*.rb') }.flatten
PLUGIN_RAKEFILES = PLUGINS.collect {|dir| dir + 'Rakefile' }
PLUGIN_SPECFILES = PLUGINS.collect {|dir| Pathname.glob(dir + 'spec/**/*_spec.rb') }.flatten

require RAKE_TASKDIR + 'helpers.rb'

### Package constants
PKG_NAME      = 'thingfish'
PKG_VERSION   = find_pattern_in_file( /VERSION = '(\d+\.\d+\.\d+)'/, LIBDIR + 'thingfish.rb' ).first
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

RELEASE_NAME  = "REL #{PKG_VERSION}"

if Rake.application.options.trace
	$trace = true
	log "$trace is enabled"
end

if Rake.application.options.dryrun
	$dryrun = true
	log "$dryrun is enabled"
	Rake.application.options.dryrun = false
end

# Load task plugins
require RAKE_TASKDIR + 'svn.rb'
require RAKE_TASKDIR + 'verifytask.rb'
Pathname.glob( RAKE_TASKDIR + '*.rb' ).each do |tasklib|
	trace "Loading task lib #{tasklib}"
	begin
		require tasklib
	rescue => err
		fail "Tasklib #{tasklib}: #{err.message}"
	end
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
multitask :docs => [ :manual, :coverage, :rdoc ] do
	log "All documentation built."
end


### Task: manual
require 'misc/rake/lib/manual'

directory MANUALOUTPUTDIR.to_s
directory RDOCDIR.to_s

Manual::GenTask.new do |manual|
	manual.metadata.version = PKG_VERSION
	manual.metadata.api_dir = RDOCDIR
	manual.output_dir = MANUALOUTPUTDIR
	manual.base_dir = MANUALDIR
	manual.source_dir = 'src'
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

