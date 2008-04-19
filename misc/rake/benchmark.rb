# 
# Benchmarking Tasks and Helpers
# $Id$
# 
# Authors:
# * Michael Granger
# * Mahlon E. Smith
# 

require 'open3'
require 'digest/md5'
require 'rake/tasklib'
require 'thingfish/client'
require 'thingfish/config'
require 'thingfish/daemon'

require 'gruff'


class BenchmarkTask < Rake::Task

	BENCH_CONFIG_DEFAULTS = {
		:concurrency => 5,
		:count => 300,
	}


	### Create a new benchmark task
	def initialize( *args )
		super

		@datapoints = {}
		@rundata = {}
		@daemon = nil
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
		trace "Running the %s benchmark with config %p" % [ self.name, configobj ]
		begin
			trace "Using config object 0x%0x" % [ configobj.object_id * 2 ]
			@config = configobj
			@daemon = ThingFish::Daemon.new( @config )

			log "Starting configured ThingFish daemon"
			Signal.trap( 'INT'  ) { @daemon.shutdown("Interrupted") }
			Signal.trap( 'TERM' ) { @daemon.shutdown("Terminated") }
			@daemon_thread = @daemon.run
			
			@benchmark_config = BENCH_CONFIG_DEFAULTS.merge( benchmark_config )
			self.instance_eval( &block )
			
			process_results( @datapoints )
		ensure
			trace "Clearing out the config objects"
			@daemon.shutdown("Benchmarks done") if @daemon

			@benchmark_config = nil
			@config = nil
		end
	end


	### Process the results into a useful format
	def process_results( datapoints )
		timestamp = Time.now.strftime('%Y%m%d-%H%M%S')
		benchmarkname = self.name[ /.*:(.*)$/, 1 ]
		
		savefile = BASEDIR + "#{benchmarkname}-benchmark.%s" % [ timestamp ]
		savefile.open( File::CREAT|File::EXCL|File::WRONLY ) do |fh|
			Marshal.dump( datapoints, fh )
		end

		datapoints.each do |name, timedata|
			datasets = timedata.transpose

			g = Gruff::StackedArea.new( 1200 )
			g.theme_keynote
			g.title = "ThingFish Benchmark -- #{name}"
			g.title_font_size = 14
			g.y_axis_increment = 10
			g.y_axis_label = "Time (ms)"
			g.x_axis_label = "%d Requests Over %0.3f seconds" % [
				datasets.first.length - 1,
				(Float( datasets[1][-1] ) - Float( datasets[1][1] )) / 1000000.0
			  ]

			# plot "http_benchmark.txt" using 7 with lines title "ctime", \
			#      "http_benchmark.txt" using 8 with lines title "dtime", \
			#      "http_benchmark.txt" using 9 with lines title "ttime", \
			#      "http_benchmark.txt" using 10 with lines title "wait"

			max = 0
			datasets[ 2..5 ].each do |data|
				values = data[1..-1].collect {|i| Integer(i) }
				max += values.max
				g.data( data[0], values )
			end

			g.maximum_value = max
			g.labels = {
				0 => "0",
				(datasets.first.length - 2) => (datasets.first.length - 2).to_s
			}

			graphname = "%s-%s" % [ benchmarkname, name.gsub(/\W+/, '_') ]
			graph_file = BASEDIR + "#{graphname}-#{timestamp}.png"
			log "Writing graph to #{graph_file}"
			g.write( graph_file.to_s )
		end
	end
	

	### Define a datapoint in the current benchmark for a given config
	def datapoint( name, http_method=:get, uri="/", options={} )
		raise "Not in a config section" unless @config
		
		log "Adding the '#{name}' datapoint"
		trace " ab config '%s %s' on %s port %d: concurrency: %d, iterations: %d" % [
			http_method.to_s.upcase,
			uri,
			@config[:ip],
			@config[:port],
			@benchmark_config[:concurrency],
			@benchmark_config[:count]
		  ]
		
		configsum = Digest::MD5.hexdigest( @config.to_h.to_yaml )
		resultsfile = BASEDIR + "ab-results.#{configsum}.#{Process.pid}.tsv"
		
		# Stuff to add to the benchmark config
		# - timed benchmark instead of count
		# - Arbitrary request header manipulation
		# - AB verbosity
		ab = [
			'/usr/sbin/ab',
			'-g', resultsfile.to_s,
			'-n', @benchmark_config[:count].to_s,
			'-c', @benchmark_config[:concurrency].to_s,
			"#{@config.ip}:#{@config.port}#{uri}"
		  ]
		
		trace "Running command: #{ab.join(' ')}"
		Open3.popen3( *ab ) do |stdin, stdout, stderr|
			trace "In the open3 block"
			stdin.close
			trace( stderr.gets ) until stderr.eof?
			trace( stdout.gets ) until stdout.eof?
		end
		trace( "ab exited with code: %d" % [ $? ] )
		
		
		@datapoints[ name ] = []
		resultsfile.each_line do |line|
			@datapoints[ name ] << line.chomp.split( /\t/ )
		end
	ensure
		resultsfile.delete if resultsfile && resultsfile.exist?
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
				config.plugins.handlers << 
					{"simplemetadata"=>{"resource_dir"=>"var/www", "uris"=>"/metadata"}} <<
					{"simplesearch"=>{"resource_dir"=>"var/www", "uris"=>"/search"}}
				config.plugins.filters << ['ruby']
			end

			with_config( config, :count => 500, :concurrency => 5 ) do
				resource = prep do |client|
					res = ThingFish::Resource.from_file( TESTIMAGE, :format => 'image/jpeg' )
					res.extent = TESTIMAGE.size
					client.store( res )
					res
				end
				
				datapoint 'GET /',                :get,  "/"
				datapoint 'GET /«uuid»',          :get,  "/#{resource.uuid}"
				datapoint 'POST /',               :post, '/', :entity_body => TESTIMAGE
				datapoint 'PUT /«uuid»',          :put,  "/#{resource.uuid}", :entity_body => TESTIMAGE
				datapoint 'GET /search',          :get,  '/search?format=image/jpeg'
				datapoint 'GET /metadata/«uuid»', :get,  "/metadata/#{resource.uuid}"
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


