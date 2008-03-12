# 
# Testing Rake Tasks for ThingFish
# $Id$
# 
# 


# Keep these tasks optional by handling LoadErrors with stub task
# replacements.
begin
	gem 'rspec', '>= 1.1.1'
	require 'spec/rake/spectask'

	COMMON_SPEC_OPTS = ['-c', '-f', 's']

	### Task: spec
	Spec::Rake::SpecTask.new( :spec ) do |task|
		task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
		task.libs += [LIBDIR]
		task.spec_opts = COMMON_SPEC_OPTS
	end
	task :test => [:spec]


	namespace :spec do
		desc "Run specs for the included plugins"
		Spec::Rake::SpecTask.new( :plugins ) do |task|
			task.spec_files = PLUGIN_SPECFILES
			task.libs += [LIBDIR] + PLUGIN_LIBS
			task.spec_opts = COMMON_SPEC_OPTS
		end

		desc "Run rspec every time there's a change to one of the files"
        task :autotest do
            require 'autotest/rspec'

			### Mmmm... smells like monkeys
			class Autotest::Rspec

				### Search the path for 'spec' in addition to the simple included methods
				### for finding it.
				def spec_commands
					path = ENV['PATH'].split( File::PATH_SEPARATOR )
					return path.collect {|dir| File.join(dir, 'spec') } +
					[
						File.join('bin', 'spec'),
						File.join(Config::CONFIG['bindir'], 'spec')
					]
				end

			end

            autotester = Autotest::Rspec.new

			autotester.exceptions = %r{\.svn|\.skel}
            autotester.test_mappings = {
                %r{^spec/.*\.rb$} => proc {|filename, _|
                    filename
                },
                %r{^lib/thingfish/([^/]*)\.rb$} => proc {|_, m|
                    ["spec/#{m[1]}_spec.rb"]
                },
                %r{^lib/thingfish/(.*)/(.*)\.rb$} => proc {|_, m|
                    ["spec/#{m[2] + m[1]}_spec.rb", "spec/#{m[1]}/#{m[2]}_spec.rb"]
                },
                %r{^plugins/(.*?)/.*\.rb$} => proc {|_, m|
                    autotester.files_matching %r{plugins/#{m[1]}/spec/.*_spec.rb}
                },
                %r{^spec/lib/(.*)_behavior\.rb$} => proc {|_, m|
                    autotester.files_matching %r{^.*#{m[0]}_spec\.rb$}
                },
            }
            
            autotester.run
        end

	
		desc "Generate HTML output for a spec run"
		Spec::Rake::SpecTask.new( :html ) do |task|
			task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
			task.spec_opts = ['-f','h', '-D']
		end

		desc "Generate plain-text output for a CruiseControl.rb build"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
			task.spec_opts = ['-f','p']
		end
	end
rescue LoadError => err
	task :no_rspec do
		$stderr.puts "Testing tasks not defined: RSpec rake tasklib not available: %s" %
			[ err.message ]
	end
	
	task :spec => :no_rspec
	namespace :spec do
		task :autotest => :no_rspec
		task :html => :no_rspec
		task :text => :no_rspec
	end
end



### RCov (via RSpec) tasks
begin
	gem 'rcov'
	gem 'rspec', '>= 1.1.1'

	COVERAGE_TARGETDIR = STATICWWWDIR + 'coverage'

	RCOV_OPTS = ['--exclude', SPEC_EXCLUDES, '--xrefs', '--save']

	### Task: coverage (via RCov)
	### Task: spec
	desc "Build test coverage reports"
	Spec::Rake::SpecTask.new( :coverage ) do |task|
		task.spec_files = SPEC_FILES + PLUGIN_SPECFILES
		task.libs += [LIBDIR] + PLUGIN_LIBS
		task.spec_opts = ['-f', 'p', '-b']
		task.rcov_opts = RCOV_OPTS
		task.rcov = true
	end
	task :coverage do
		rmtree( COVERAGE_TARGETDIR )
		cp_r( 'coverage', COVERAGE_TARGETDIR, :verbose => true )
	end


	task :rcov => [:coverage] do; end
	
	### Other coverage tasks
	namespace :coverage do
		desc "Generate a detailed text coverage report"
		Spec::Rake::SpecTask.new( :text ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = RCOV_OPTS + ['--text-report']
			task.rcov = true
		end

		desc "Show differences in coverage from last run"
		Spec::Rake::SpecTask.new( :diff ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--text-coverage-diff']
			task.rcov = true
		end

		### Task: verify coverage
		desc "Build coverage statistics"
		VerifyTask.new( :verify => :rcov ) do |task|
			task.threshold = 85.0
		end
		
		desc "Run RCov in 'spec-only' mode to check coverage from specs"
		Spec::Rake::SpecTask.new( :speconly ) do |task|
			task.spec_files = SPEC_FILES
			task.libs += FileList['plugins/**/lib']
			task.rcov_opts = ['--exclude', SPEC_EXCLUDES, '--text-report', '--save']
			task.rcov = true
		end
	end

	task :clobber_coverage do
		rmtree( COVERAGE_TARGETDIR )
	end

rescue LoadError => err
	task :no_rcov do
		$stderr.puts "Coverage tasks not defined: RSpec+RCov tasklib not available: %s" %
			[ err.message ]
	end

	task :coverage => :no_rcov
	task :clobber_coverage
	task :rcov => :no_rcov
	namespace :coverage do
		task :text => :no_rcov
		task :diff => :no_rcov
	end
	task :verify => :no_rcov
end


