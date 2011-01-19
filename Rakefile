#!/usr/bin/env rake
#encoding: utf-8

require 'pathname'
require 'hoe'

# Directory to keep benchmarks around in
BASEDIR      = Pathname( __FILE__ ).dirname
BENCHMARKDIR = BASEDIR + 'benchmarks'
MISCDIR      = BASEDIR + 'misc'
TESTIMAGE    = MISCDIR + 'testimage.jpg'


Hoe.plugin :mercurial
Hoe.plugin :yard
Hoe.plugin :signing
Hoe.plugin :manualgen

Hoe.plugins.delete :rubyforge


hoespec = Hoe.spec 'thingfish' do
	self.readme_file = 'README.md'
	self.history_file = 'History.md'

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'
	self.developer 'Mahlon E. Smith', 'mahlon@martini.nu'

	self.extra_deps.push *{
		'pluginfactory' => "~> 1.0.4",
		'uuidtools'     => "~> 2.1.1",
	}
	self.extra_dev_deps.push *{
		'rspec'        => '~> 2.4.0',
		'tidy-ext'     => '~> 0.1.10',
		'sqlite3-ruby' => '~> 1.3.2',
		'ruby-mp3info' => '~> 0.6.13',
		'exifr'        => "~> 1.0.3",
		'json'         => "~> 1.4.6",
		'rmagick'      => "~> 2.13.1",
		'sequel'       => "~> 3.19.0",
		'lockfile'     => "~> 1.4.3",
	}

	self.spec_extras[:licenses] = ["BSD"]
	self.spec_extras[:post_install_message] = %{

		You can start the server with 'thingfishd', and talk to a running ThingFish 
		server with the 'thingfish' command.
		
	}.gsub( /^\t{2}/, '' )

	self.spec_extras[:signing_key] = '/Volumes/Keys/ged-private_gem_key.pem'
	self.require_ruby_version( '>=1.9.2' )

	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.yard_opts = [ '--use-cache', '--protected', '--verbose' ] if
		self.respond_to?( :yard_opts= )

	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

task 'hg:precheckin' => :spec

begin
	include Hoe::MercurialHelpers

	### Task: prerelease
	desc "Append the package build number to package versions"
	task :pre do
		rev = get_numeric_rev()
		trace "Current rev is: %p" % [ rev ]
		hoespec.spec.version.version << "pre#{rev}"
		Rake::Task[:gem].clear

		Gem::PackageTask.new( hoespec.spec ) do |pkg|
			pkg.need_zip = true
			pkg.need_tar = true
		end
	end

	### Make the ChangeLog update if the repo has changed since it was last built
	file '.hg/branch'
	file 'ChangeLog' => '.hg/branch' do |task|
		$stderr.puts "Updating the changelog..."
		content = make_changelog()
		File.open( task.name, 'w', 0644 ) do |fh|
			fh.print( content )
		end
	end

	# Rebuild the ChangeLog immediately before release
	task :prerelease => 'ChangeLog'

rescue NameError => err
	task :no_hg_helpers do
		fail "Couldn't define the :pre task: %s: %s" % [ err.class.name, err.message ]
	end

	task :pre => :no_hg_helpers
	task 'ChangeLog' => :no_hg_helpers

end

begin
	require 'thingfish/benchmarktask'

	namespace :benchmarks do

		file TESTIMAGE.to_s

		desc "Run all benchmarks"
		task :all do |alltask|
			log "Running all benchmark tasks"
			subtasks = Rake::Task.tasks.select {|t| t.name =~ /^benchmarks:/ }
			subtasks.each do |task|
				next if task.name =~ /benchmarks:(all|graphs)/
				trace "  considering invoking task #{task}"
				task.invoke
			end
		end

		desc "Benchmark the default handler in a stripped-down server"
		benchmark :barebones => [TESTIMAGE.to_s] do
			config = ThingFish::Config.new do |config|
				config.ip = '127.0.0.1'
				config.port = 55555
				config.logging.level = 'error'
				config.logging.logfile = 'stderr'
				config.plugins.filestore.maxsize = TESTIMAGE.size * 1000
				config.plugins.urimap = {
					'/metadata' =>
						[{ 'simplemetadata' => {'resource_dir' => 'data/thingfish/web-interface'} }],
					'/search'   =>
						[{ 'simplesearch'   => {'resource_dir' => 'data/thingfish/web-interface'} }]
				}
				config.plugins.filters << ['ruby', 'yaml']
			end

			headers = {
				'Accept' => 'text/x-yaml',
				'Accept-Encoding' => 'utf8',
			}

			with_config( config, :count => 500, :concurrency => 5, :headers => headers ) do # DataSet
				resource = prep do |client|
					res = ThingFish::Resource.from_file( TESTIMAGE, :format => 'image/jpeg' )
					res.extent = TESTIMAGE.size
					client.store( res )
					res
				end

				datapoint 'GET /',					:get,  "/"
				datapoint 'GET /«uuid»',			:get,  "/#{resource.uuid}"
				datapoint 'POST /',					:post, '/', :entity_body => TESTIMAGE
				datapoint 'PUT /«uuid»',			:put,  "/#{resource.uuid}", :entity_body => TESTIMAGE
				datapoint 'GET /search',			:get,  '/search?format=image/jpeg'
				datapoint 'GET /metadata/«uuid»',	:get,  "/metadata/#{resource.uuid}"
			end

		end

		desc "Create Gruff graphs for all existing benchmark data"
		task :graphs do
			datafiles = Pathname.glob( BENCHMARKDIR + '**/*.data' )

			datafiles.each do |datafile|
				log "Generating graphs from #{datafile}"
				dataset = Marshal.load( File.open(datafile, 'r') )
				dataset.generate_gruff_graphs( datafile.dirname )
			end
		end

	end
rescue LoadError => err
	task :no_benchmarks do
		$stderr.puts "Benchmark tasks not defined: %s" % [ err.message ]
	end

	namespace :benchmarks do
		task :all => :no_benchmarks
		task :graphs => :no_benchmarks
		task :barebones => :no_benchmarks
	end
end

task :benchmarks => [ 'benchmarks:all' ]
task :bench => :benchmarks

