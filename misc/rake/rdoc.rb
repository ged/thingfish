# 
# RDoc Rake tasks for ThingFish
# $Id$
# 

require 'rake/rdoctask'

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

