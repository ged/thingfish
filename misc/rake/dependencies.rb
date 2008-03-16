# 
# Dependency-checking and Installation Rake Tasks for ThingFish
# $Id$
# 

require 'rubygems/remote_installer'
require 'rubygems/doc_manager'

# Monkeypatch to work around the bug in #install -- after 1.0,
# new_installer() no longer takes arguments other than the destination_file.
class Gem::RemoteInstaller
	def install(gem_name, version_requirement = Gem::Requirement.default,
		force = false, install_dir = Gem.dir)
		unless version_requirement.respond_to?(:satisfied_by?)
			version_requirement = Gem::Requirement.new [version_requirement]
		end

		installed_gems = []

		begin
			spec, source = find_gem_to_install(gem_name, version_requirement)
			dependencies = find_dependencies_not_installed(spec.dependencies)

			installed_gems << install_dependencies(dependencies, force, install_dir)

			cache_dir = @options[:cache_dir] || File.join(install_dir, "cache")
			destination_file = File.join(cache_dir, spec.full_name + ".gem")

			download_gem(destination_file, source, spec)

			installer = new_installer( destination_file )
			installed_gems.unshift( installer.install )
		rescue Gem::RemoteInstallationSkipped => e
			alert_error e.message
		end

		installed_gems.flatten
	end
end


### Install the specified +gems+ if they aren't already installed.
def install_gems( *gems )
	gems.flatten!
	
	# Check for root
	if Process.euid != 0
		$stderr.puts "This probably won't work, as you aren't root, but I'll try anyway"
	end

	installer = Gem::RemoteInstaller.new( :include_dependencies => true )
	gemindex = Gem::SourceIndex.from_installed_gems

	gems.each do |gemname|
		if (( specs = gemindex.search(gemname) )) && ! specs.empty?
			log "Version %s of %s is already installed; skipping..." % 
				[ specs.first.version, specs.first.name ]
			next
		end

		log "Trying to install #{gemname}..."
		gems = installer.install( gemname )
		gems.compact!
		log "Installed: %s" % [gems.collect {|spec| spec.full_name}.join(', ')]

		gems.each do |gem|
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_ri
			Gem::DocManager.new( gem, '-w4 -SNH' ).generate_rdoc
		end
	end
end

	

### Task: install gems for development tasks
DEPENDENCIES = %w[
	mongrel pluginfactory rcov uuidtools rote rspec lockfile rcodetools coderay redcloth
  ]
task :install_dependencies do
	install_gems( *DEPENDENCIES )
end

NONGEM_INSTALLS = {
	:cl_xmlserial => 'http://prdownloads.sourceforge.net/clxmlserial/clxmlserial.1.0.pre4.zip'
}

### Task: install gems for plugins
PLUGIN_DEPENDENCIES = %w[json exifr ruby-mp3info tidy sqlite3-ruby sequel]
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


