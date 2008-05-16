# 
# Dependency-checking and Installation Rake Tasks for ThingFish
# $Id$
# 

require 'rubygems/dependency_installer'
require 'rubygems/source_index'
require 'rubygems/requirement'
require 'rubygems/doc_manager'

### Install the specified +gems+ if they aren't already installed.
def install_gems( *gems )
	gems.flatten!
	
	defaults = Gem::DependencyInstaller::DEFAULT_OPTIONS.merge({
		:generate_rdoc     => true,
		:generate_ri       => true,
		:install_dir       => Gem.dir,
		:format_executable => false,
		:test              => false,
		:version           => Gem::Requirement.default,
	  })
    
	# Check for root
	if Process.euid != 0
		$stderr.puts "This probably won't work, as you aren't root, but I'll try anyway"
	end

	gemindex = Gem::SourceIndex.from_installed_gems

	gems.each do |gemname|
		if (( specs = gemindex.search(gemname) )) && ! specs.empty?
			log "Version %s of %s is already installed; skipping..." % 
				[ specs.first.version, specs.first.name ]
			next
		end

		log "Trying to install #{gemname.inspect}..."
		installer = Gem::DependencyInstaller.new
		installer.install( gemname )

		installer.installed_gems.each do |spec|
			log "Installed: %s" % [ spec.full_name ]
		end

	end
end



### Task: install gems for development tasks
DEPENDENCIES = %w[
	mongrel pluginfactory rcov uuidtools rspec lockfile rcodetools uv redcloth
  ]
task :install_dependencies do
	install_gems( *DEPENDENCIES )
end

NONGEM_INSTALLS = {
	:cl_xmlserial => 'http://prdownloads.sourceforge.net/clxmlserial/clxmlserial.1.0.pre4.zip'
}

### Task: install gems for plugins
PLUGIN_DEPENDENCIES = %w[json exifr ruby-mp3info tidy sqlite3-ruby sequel tmail]
task :install_plugin_dependencies do
	
	workdir = Pathname.new( Dir.tmpdir )
	unzip = which( 'unzip' ) or
		fail "Can't extract downloads: unzip: no such file or directory"
	
	install_gems( *PLUGIN_DEPENDENCIES )

	# Install RMagick
	# Install cl/xmlfilter
	targetzip = workdir + 'clxmlserial.zip'
	download( NONGEM_INSTALLS[:cl_xmlserial], targetzip )
	system( unzip, '-d', workdir, targetzip )
	clxmldir = workdir + 'clxmlserial'
	Dir.chdir( clxmldir ) do
		ruby( 'install.rb' )
	end
end


