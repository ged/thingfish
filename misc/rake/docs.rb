# 
# RDoc Rake tasks for ThingFish
# $Id$
# 

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent
	docsdir = basedir + 'docs'
	docslibdir = docsdir + 'lib'
	
	$LOAD_PATH.unshift( docslibdir.to_s ) unless $LOAD_PATH.include?( docslibdir.to_s )
}

require 'rake/rdoctask'

RDOC_OPTIONS = [
	'-w', '4',
	'-SHN',
	'-i', BASEDIR.to_s,
	'-m', 'README',
	'-W', 'http://opensource.laika.com/browser/thingfish/trunk/'
  ]

# Try to require Darkfish for rdoc, but don't mandate it
begin
	require 'rubygems'
	gem 'darkfish-rdoc'
rescue LoadError => err
	trace "Darkfish gem failed: #{err.message}"
end # (ignored)

begin
	require 'darkfish-rdoc'
	RDOC_OPTIONS << '-f' << 'darkfish'
rescue LoadError => err
	trace "Darkfish failed to load: #{err.message}"
end # (ignored)

directory RDOCDIR.to_s

### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = RDOCDIR.to_s
	rdoc.title    = "ThingFish - A highly-accessable network datastore"

	rdoc.options += RDOC_OPTIONS

	rdoc.rdoc_files.include 'README'
	rdoc.rdoc_files.include 'QUICKSTART'
	rdoc.rdoc_files.include LIB_FILES.collect {|f| f.relative_path_from(BASEDIR).to_s }
end
task :clobber_rdoc do
	rmtree( STATICWWWDIR + 'api', :verbose => true )
end


### Task: manual generation
begin
	require 'misc/rake/lib/manual'

	directory MANUALOUTPUTDIR.to_s

	Manual::GenTask.new do |manual|
		manual.metadata.version = PKG_VERSION
		manual.metadata.api_dir = RDOCDIR
		manual.output_dir = MANUALOUTPUTDIR
		manual.base_dir = MANUALDIR
		manual.source_dir = 'src'
	end

	task :clobber_manual do
		rmtree( MANUALOUTPUTDIR, :verbose => true )
	end

rescue LoadError => err
	task :no_manual do
		$stderr.puts "Manual-generation tasks not defined: %s" % [ err.message ]
	end

	task :manual => :no_manual
	task :clobber_manual => :no_manual
end



