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
Hoe.plugin :signing
Hoe.plugin :manualgen

Hoe.plugins.delete :rubyforge


hoespec = Hoe.spec 'thingfish' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = Rake::FileList[ '*.rdoc' ]

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'
	self.developer 'Mahlon E. Smith', 'mahlon@martini.nu'

	self.dependency 'pluginfactory', '~> 1.0'
	self.dependency 'uuidtools',     '~> 2.1'
	self.dependency 'hoe-deveiate',  '~> 0.0',  :development
	self.dependency 'tidy-ext',      '~> 0.1',  :development
	self.dependency 'sqlite3',       '~> 1.3',  :development
	self.dependency 'ruby-mp3info',  '~> 0.6',  :development
	self.dependency 'exifr',         '~> 1.0',  :development
	self.dependency 'json',          '~> 1.4',  :development
	self.dependency 'rmagick',       '~> 2.13', :development
	self.dependency 'sequel',        '~> 3.31', :development
	self.dependency 'lockfile',      '~> 1.4',  :development

	self.spec_extras[:licenses] = ["BSD"]
	self.spec_extras[:post_install_message] = %{

		You can start the server with 'thingfishd', and talk to a running ThingFish 
		server with the 'thingfish' command.

	}.gsub( /^\t{2}/, '' )

	self.require_ruby_version( '>=1.9.3' )

	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

task 'hg:precheckin' => [ 'ChangeLog', :check_manifest, :check_history, :spec ]


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

