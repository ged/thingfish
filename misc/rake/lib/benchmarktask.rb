# 
# Benchmarking Task library
# $Id$
# 
# Authors:
# * Michael Granger <ged@faeriemud.org>
# * Mahlon E. Smith <mahlon@martini.nu>
# 

require 'open3'
require 'digest/md5'
require 'rake/tasklib'
require 'misc/rake/svn'
require 'thingfish/client'
require 'thingfish/config'
require 'thingfish/daemon'


module Benchmark
	
	begin
		require 'gruff'
		HAVE_GRUFF = true
	rescue LoadError
		HAVE_GRUFF = false
	end
	
	### An object class for encapsulating a single datapoint in a benchmark dataset
	class Datapoint

		### Column constants: indexes into members of the @times array
		EPOCHTIME = 0
		CTIME     = 1
		DTIME     = 2
		TTIME     = 3
		WAIT      = 4


		### Create a new Datapoint for the given +http_method+ (which should be a 
		### Symbol like :get or :put), +uri+, and +options+ hash. Uses the specified
		### +name+ when used in text or graphical output.
		def initialize( name, http_method, uri, ab_output, bench_config, options={} )
			@name         = name
			@http_method  = http_method
			@uri          = uri
			@ab_output    = ab_output
			@bench_config = bench_config
			@options      = options
		
			@times        = []
		end


		######
		public
		######
	
		# The name of the datapoint
		attr_reader :name
		
		# The HTTP method of the requests run for the datapoint
		attr_reader :http_method
		
		# The URI of the requests run for the datapoint
		attr_reader :uri
		
		# The statistics that ab generates on stdout
		attr_reader :ab_output

		# The config hash for the benchmark this datapoint is a member of
		attr_reader :bench_config
		
		# The options that were used to configure the requests run for the datapoint 
		attr_reader :options


		### Append a row of output from 'ab' to the times for this datapoint
		def <<( row )
			@times << row.chomp.split( /\t/ )[ 1..-1 ].collect {|i| Integer(i) }
			return self
		end
		
		
		### Return the Time of the start of the benchmark
		def start_time
			epochseconds = @times.first[EPOCHTIME] / 1_000_000.0
			return Time.at( epochseconds )
		end
		
		
		### Return the Time of the end of the benchmark
		def finish_time
			epochseconds = @times.last[EPOCHTIME] / 1_000_000.0
			return Time.at( epochseconds )
		end
		
		
		### Return the number of requests processed in this benchmark
		def count
			@times.length
		end
		
		
		### Return the concurrency 'ab' used when running the benchmark
		def concurrency
			@bench_config[:concurrency]
		end
		
		
		### Return the number of seconds the benchmark took (as a Float)
		def runtime
			return self.finish_time - self.start_time
		end
		
		
		### Return the number of requests per second executed in this datapoint.
		def requests_per_second
			return self.count / self.runtime
		end
		
		
		### Generate timing statistics methods for the given +column+ of `ab` output.
		def self::def_time_methods( column, name=column )
			columnidx = const_get( column.to_s.upcase ) or
				raise ScriptError, "no column constant called #{column.to_s.upcase}"

			define_method( "#{name}_times" ) do
				@times.transpose[ columnidx ]
			end
			alias_method "#{column}s", "#{name}_times" unless name == column
			
			define_method( "min_#{name}_time" ) do
				@times.transpose[columnidx].min
			end
			alias_method "min_#{column}", "min_#{name}_time"
			
			define_method( "max_#{name}_time" ) do
				@times.transpose[columnidx].max
			end
			alias_method "max_#{column}", "max_#{name}_time"
			
			define_method( "mean_#{name}_time" ) do
				@times.transpose[columnidx].inject(0) {|sum,n| sum + n } / self.count.to_f
			end
			alias_method "mean_#{column}", "mean_#{name}_time"
			
			define_method( "#{name}_time_standard_deviation" ) do
				standard_deviation( self.send("#{name}_times") )
			end
			alias_method "#{column}_standard_deviation", "#{name}_time_standard_deviation"
			
			define_method( "#{name}_time_histogram" ) do
				return @times.transpose[columnidx].inject({}) {|hist,n|
					hist[ n ] ||= 0
					hist[ n ] += 1
					hist
				}
			end
		end
		
		
		def_time_methods :dtime, :processing
		def_time_methods :ctime, :connecting
		def_time_methods :ttime, :total
		def_time_methods :wait


		### Return a brief synopsis of the times currently in the datapoint
		def synopsis
			return "%0.5f seconds @%0.1f req/s (mean) [proc mean: %dms +/- %0.2fms]" % [
				self.runtime,
				self.requests_per_second,
				self.mean_processing_time,
				self.processing_time_standard_deviation,
			]
		end
		
		
		#######
		private
		#######

		### Calculate the variance in a +population+. 
		### Stolen from http://warrenseen.com/blog/2006/03/13/how-to-calculate-standard-deviation/
		def variance( population )
			n = 0
			mean = 0.0
			s = 0.0

			population.each do |x|
				n = n + 1
				delta = x - mean
				mean = mean + (delta / n)
				s = s + delta * (x - mean)
			end

			# if you want to calculate std deviation
			# of a sample change this to "s / (n-1)"
			return s / n.to_f
		end


		### Calculate the standard deviation of a +population+
		def standard_deviation( population )
			Math.sqrt( variance(population) )
		end
	end


	### An object class that encapsulates one or more datapoints gathered while running
	### ThingFish in a particular configuration, and which provides methods for 
	### generating output from the datapoints as graphs or text reports.
	class Dataset

		### Create a new Benchmark dataset object with the given name, ThingFish daemon config, 
		### and benchmark config.
		def initialize( name, config, benchmark_config )
			@name = name
			@datapoints = []
			@config = config
			@benchmark_config = benchmark_config
		end


		######
		public
		######
		
		# The name of the dataset
		attr_reader :name

		# The datapoints gathered for the dataset
		attr_reader :datapoints

		# The ThingFish::Config used to configure the ThingFish daemon the dataset was run
		# against
		attr_reader :config

		# Benchmarking config options passed to with_config()
		attr_reader :benchmark_config
		

		### Append a Benchmark::Datapoint to the dataset
		def <<( datapoint )
			@datapoints << datapoint
			return self
		end
	

		### Create pretty graphs using the Gnuplot binary.
		def generate_gnuplot_graphs( outputdir )
			unless gnuplot = which('gnuplot')
				trace "Skipping Gnuplot graph generation: Gnuplot not found in path."
				return
			end
		
			gp_io = open( '|-', 'w+' ) or exec gnuplot
		
			# gp_io.puts
		end


		### Return the name of the dataset after trimming off the leading namespace.
		def simplename
			return self.name.sub(/.*:/, '')
		end
		

		### Create pretty graphs using the Gruff library.
		def generate_gruff_graphs( outputdir )
			unless HAVE_GRUFF
				trace "Skipping Gruff graph generation: Gruff does not appear to be installed."
				return
			end

			self.generate_gruff_requesttime_graphs( outputdir )
			self.generate_gruff_histogram_graph( outputdir )
		end


		### Create a graph that shows a histogram of request times.
		def generate_gruff_histogram_graph( outputdir )
			g = Gruff::Line.new( 1200 )
			g.theme_keynote
			g.title = "ThingFish Wait Time Histogram -- #{simplename()}"
			g.title_font_size = 14
			g.y_axis_label = "# of Reqests"
			g.x_axis_label = "Time (ms)"
			g.marker_font_size = 12
			g.legend_font_size = 10
			g.hide_dots = true

			range = (0..@datapoints.collect {|dp| dp.max_wait }.max)
			valuehash = range.inject({}) {|h,i| h[i] = 0; h }

			@datapoints.each do |datapoint|
				table = valuehash.dup
				datapoint.wait_time_histogram.each do |time, count|
					table[ time ] = count
				end
				g.data( datapoint.name, table.sort_by {|t,c| t }.transpose[1] )
			end

			labels = {}
			range.step( range.end / 15 ) {|i| labels[i] = i.to_s }
			g.labels = labels

			graph_file = outputdir + "#{simplename()}-histogram.png"
			log "Writing graph to #{graph_file}"
			g.write( graph_file.to_s )
		end
		
		
		### Create a graph for each datapoint showing total request times
		def generate_gruff_requesttime_graphs( outputdir )
			@datapoints.each do |datapoint|
				graphname = "%s-%s" % [ simplename(), datapoint.name.gsub(/\W+/, '_') ]

				g = Gruff::StackedArea.new( 1200 )
				g.theme_keynote
				g.title = "ThingFish Benchmark -- #{datapoint.name} (#{simplename()})"
				g.title_font_size = 14
				g.maximum_value = datapoint.max_total_time + datapoint.max_wait_time
				g.minimum_value = 0
				g.y_axis_label = "Time (ms)"
				g.x_axis_label = "%d Requests Over %0.3f seconds, %0.2f requests/s (mean)" % [
					datapoint.count,
					datapoint.runtime,
					datapoint.requests_per_second
				  ]

				labels = {}
				(0..datapoint.count).step( datapoint.count / 5 ) do |n|
					labels[ n ] = n.to_s
				end
				g.labels = labels

				trace "  adding connecting times to the graph: %p" % [ datapoint.connecting_times[0,5] ]
				g.data( "Connection", datapoint.connecting_times )
				trace "  adding wait times to the graph: %p" % [ datapoint.wait_times[0,5] ]
				g.data( "Wait", datapoint.wait_times )
				trace "  adding processing times to the graph: %p" % [ datapoint.processing_times[0,5] ]
				g.data( "Processing", datapoint.processing_times )

				graph_file = outputdir + "#{graphname}.png"
				log "Writing graph to #{graph_file}"
				g.write( graph_file.to_s )
			end
		end
	end


	### A rake task for generating ThingFish benchmarks using 'ab'
	class Task < Rake::Task

		BENCHMARKS_DIR = Pathname.new( 'benchmarks' )

		BENCH_CONFIG_DEFAULTS = {
			:concurrency => 5,
			:count => 300,
		}
		
		AB_PATCH_LOCATION = "https://issues.apache.org/bugzilla/show_bug.cgi?id=44851"


		### Define subordinate tasks for benchmarks before the main task is defined
		def self::define_task( *args, &block )
			task = super

			directory BENCHMARKS_DIR.to_s
			nsname = task.name.gsub( /.*:/, '' )
			desc "Clobber output for the #{nsname} benchmarks"
			task "clobber_#{nsname}" do
				# TODO
			end
			return task
		end


		### Create a new benchmark task
		def initialize( *args )
			super

			@daemon = nil
			@config = nil
			@dataset = nil
			@outputdir = BENCHMARKS_DIR + "r%d" % [get_svn_rev( BASEDIR )]
			@outputdir.mkpath
		end

	
		######
		public
		######

		# The name of the benchmark
		attr_reader :name
	
		# The current dataset being generated by the benchmark
		attr_reader :dataset


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
				@benchmark_config = BENCH_CONFIG_DEFAULTS.merge( benchmark_config )
				
				@dataset = Benchmark::Dataset.new( self.name, @config, @benchmark_config )
				@daemon = ThingFish::Daemon.new( @config )

				trace "Starting configured ThingFish daemon"
				Signal.trap( 'INT'  ) { @daemon.shutdown("Interrupted") }
				Signal.trap( 'TERM' ) { @daemon.shutdown("Terminated") }
				@daemon_thread = @daemon.run
			
				self.instance_eval( &block )
			
				save_dataset()
			ensure
				trace "Clearing out the config objects"
				@daemon.shutdown("Benchmarks done") if @daemon

				@benchmark_config = nil
				@config = nil
				@dataset = nil
			end
		end


		### Process the results into a useful format
		def save_dataset
			savefile = @outputdir + "%s.data" % [ benchmarkname() ]
			savefile.open( File::CREAT|File::WRONLY ) do |fh|
				Marshal.dump( @dataset, fh )
			end
		
			return savefile
		end
	
	
		### Return a normalized version of the configured benchmark name.
		def benchmarkname
			return self.name[ /.*:(.*)$/, 1 ]
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
		
			dpname = name.gsub( /\W+/, "_" ).downcase.sub( /_$/, '' )
			resultsfile = @outputdir + "%s.%s.tsv" % [ benchmarkname(), dpname ]
		
			ab = make_ab_command( uri, http_method, resultsfile, options )
			trace( ab.collect {|part| part =~ /\s/ ? part.inspect : part} ) 

			ab_output = []
			Open3.popen3( *ab ) do |stdin, stdout, stderr|
				trace "In the open3 block"
				stdin.close
				trace( stderr.gets ) until stderr.eof?
				until stdout.eof?
					output_line = stdout.gets
					ab_output << output_line if output_line =~ /:\s+\w/
					trace( output_line ) 
				end
			end
			trace( "ab exited with code: %d" % [ $? ] )
		
			datapoint = Datapoint.new( name, http_method, uri, ab_output, @benchmark_config, options )
			resultsfile.each_line do |line|
				next if line =~ /^starttime/
				datapoint << line
			end
		
			log( "  " + datapoint.synopsis )
		
			@dataset << datapoint
		end
	
	
		### Create a command line suitable for running ab against the given +uri+, taking
		### command-line arguments from the ThingFish +config+ and +benchmark_config+.
		def make_ab_command( uri, http_method, resultsfile, options )
			abprog = which( 'ab' ) or fail "ab: no such file or directory"

			# ab capability check
			find_pattern_in_pipe( /-D\s+Send a DELETE request/, abprog, '-h' ) or
				fail "Benchmarks require patched ab, see: #{AB_PATCH_LOCATION}"
		
			ab = [ abprog, '-g', resultsfile.to_s ]

			ab << '-n' << @benchmark_config[:count].to_s       if @benchmark_config[:count]
			ab << '-c' << @benchmark_config[:concurrency].to_s if @benchmark_config[:concurrency]
			ab << '-t' << @benchmark_config[:timed].to_s       if @benchmark_config[:timed]
			
			if @benchmark_config[:headers]
				@benchmark_config[:headers].each do |header, value|
					ab << '-H' << "%s: %s" % [ header, value ]
				end
			end
			
			case http_method
			when :put
				fail "PUT requires an :entity_body" unless options[:entity_body]
				ab << '-u' << options[:entity_body]	
			when :post
				fail "POST requires an :entity_body" unless options[:entity_body]
				ab << '-p' << options[:entity_body]
			when :delete
				ab << '-D'
			when :head
				ab << '-i'
			when :get
			else
				fail "Unsupported http_method in benchmark: %s" % [ http_method ]
			end
			
			ab.push( "#{@config.ip}:#{@config.port}#{uri}" )
		
			return ab
		end
		
	
		### Create a ThingFish::Client object that will talk to the configured ThingFish daemon
		### and yield it to the block to do any necessary preparation for the benchmark. The
		### return value from the block is returned.
		def prep
			raise "Not in a config section" unless @config
		
			uri = "http://#{@config.ip}:#{@config.port}/"
			log "Creating a client object for benchmark prep: #{uri}"
			client = ThingFish::Client.new( uri )
			return yield( client )
		end
	
	
	end # class Task

end # module Benchmark


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
	task = Benchmark::Task.define_task( *args, &block )
end


