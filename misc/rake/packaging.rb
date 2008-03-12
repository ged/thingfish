# 
# Packaging Rake Tasks for ThingFish
# 
# 

require 'rake/packagetask'
require 'rake/gempackagetask'

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



