# 
# RDoc Rake tasks for ThingFish
# $Id$
# 

require 'rake/rdoctask'

# Try to require Darkfish for rdoc, but don't mandate it
begin
	require 'rubygems'
	gem 'darkfish-rdoc'
rescue LoadError; end # (ignored)

begin
	require 'rdoc/generator/darkfish'
rescue LoadError; end # (ignored)

directory RDOCDIR.to_s

### Task: rdoc
Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = RDOCDIR.to_s
	rdoc.title    = "ThingFish - A highly-accessable network datastore"

	rdoc.options += [
		'-w', '4',
		'-SHN',
		'-i', BASEDIR.to_s,
		'-m', 'README',
		'-W', 'http://opensource.laika.com/browser/thingfish/trunk/'
	  ]

	rdoc.options += [ '-f', 'darkfish' ] 
	
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



