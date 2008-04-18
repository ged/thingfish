# 
# Benchmarking Tasks and Helpers
# $Id$
# 
# Authors:
# * Michael Granger
# * Mahlon E. Smith
# 

require 'rake/tasklib'
require 'thingfish/client'
require 'thingfish/config'


class BenchmarkTask < Rake::Task

	### Create a new benchmark task
	def initialize( *args )
		super

		@datapoints = []
		@rundata = {}
		@config = nil
	end

	
	######
	public
	######

	attr_reader :name


	### Execute the task. Note that this is overridden from the base Task class's #execute
	### so it will execute in the context of the task object itself.
	def execute( args )
		if application.options.dryrun
			puts "** Execute (dry run) #{name}"
			return
		end

		if application.options.trace
			puts "** Execute #{name}"
		end

		application.enhance_with_matching_rule(name) if @actions.empty?

		@actions.each do |act|
			self.instance_eval( &act )
		end
	end
	


	#######
	private
	#######

	### Set up both a ThingFish::Config object and a benchmark config hash, and then 
	### run eval the specified block in the context of the task with the config set
	### in the @config instance variable.
	def with_config( configobj, benchmark_config={}, &block )
		log "Running the %s benchmark with config %p" % [ self.name, configobj ]
		begin
			@config = configobj
			@config.install
			@benchmark_config = benchmark_config
			log "Defined config object 0x%0x" % [ configobj.object_id * 2 ]
			self.instance_eval( &block )
		ensure
			log "Clearing out the config objects"
			@benchmark_config = nil
			@config = nil
		end
	end


	### Define a datapoint in the current benchmark for a given config
	def datapoint( name, http_method=:get, uri="/", options={} )
		raise "Not in a config section" unless @config
		
		log "Running ab '%s %s' for the '%s' datapoint" %
			[ http_method.to_s.upcase, uri, name]
		log " config: 0x%0x, concurrency: %d, iterations: %d" %
			[ @config.object_id * 2, @benchmark_config[:concurrency], @benchmark_config[:count] ]
	end
	
	
	### Create a ThingFish::Client object that will talk to the configured ThingFish daemon
	### and yield it to the block to do any necessary preparation for the benchmark. The
	### return value from the block is returned.
	def prep
		raise "Not in a config section" unless @config
		
		log "Creating a client object for benchmark prep"
		client = ThingFish::Client.new( "http://#{@config.ip}:#{@config.port}/" )
		return yield( client )
	end
	
	
end


### Declare a new Benchmark task.
### 
### Example:
### 
### benchmark :plain do
###   # ...stuff...
### 
### end
### 
def benchmark( *args, &block )
	BenchmarkTask.define_task( *args, &block )
end



begin
	gem 'gruff'

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
				config.port = 3474
				config.logging.level = 'error'
				config.logging.logfile = 'stderr'
				config.plugins.handlers << 
					{"simplemetadata"=>{"resource_dir"=>"var/www", "uris"=>"/metadata"}} <<
					{"simplesearch"=>{"resource_dir"=>"var/www", "uris"=>"/search"}}
			end

			with_config( config, :count => 5000, :concurrency => 5 ) do
				resource = prep do |client|
					res = ThingFish::Resource.from_file( TESTIMAGE, :format => 'image/jpeg' )
					res.extent = TESTIMAGE.size
					client.store( res )
					res
				end
				
				datapoint 'Default GET', :get, "/#{resource.uuid}"
				datapoint 'Default POST', :post, '/', :entity_body => TESTIMAGE
				datapoint 'Default POST', :put, "/#{resource.uuid}", :entity_body => TESTIMAGE
				datapoint 'Search Handler', :get, '/search?format=image/jpeg'
				datapoint 'Metadata Handler', :get, "/metadata/#{resource.uuid}"
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