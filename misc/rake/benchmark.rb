# 
# Benchmarking Tasks
# $Id$
# 
# Authors:
# * Michael Granger <ged@faeriemud.org>
# * Mahlon E. Smith <mahlon@martini.nu>
# 

begin
	require 'misc/rake/lib/benchmarktask'

	namespace :benchmarks do

		desc "Run all benchmarks"
		task :all do |alltask|
			log "Running all benchmark tasks"
			subtasks = Rake::Task.tasks.select {|t| t.name =~ /^benchmarks:/ }
			subtasks.each do |task|
				next if task.name == 'benchmarks:all'
				task.invoke
			end
		end
	
		TESTIMAGE = MISCDIR + 'testimage.jpg'
		file TESTIMAGE.to_s

		desc "Benchmark the default handler in a stripped-down server"
		benchmark :barebones => [TESTIMAGE.to_s] do
			config = ThingFish::Config.new do |config|
				config.ip = '127.0.0.1'
				config.port = 55555
				config.logging.level = 'error'
				config.logging.logfile = 'stderr'
				config.plugins.filestore.maxsize = TESTIMAGE.size * 502
				config.plugins.handlers << 
					{"simplemetadata"=>{"resource_dir"=>"var/www", "uris"=>"/metadata"}} <<
					{"simplesearch"=>{"resource_dir"=>"var/www", "uris"=>"/search"}}
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
	end
rescue LoadError => err
	task :no_benchmarks do
		$stderr.puts "Benchmark tasks not defined: %s" % [ err.message ]
	end

	namespace :benchmarks do
		task :all => :no_benchmarks
	end
end

task :benchmarks => [ 'benchmarks:all' ]


