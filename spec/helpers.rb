#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'

	basedir = Pathname.new( __FILE__ ).dirname.parent
	strelkadir = basedir.parent + 'Strelka'
	strelkalibdir = strelkadir + 'lib'
	mongrel2dir = basedir.parent + 'Mongrel2'
	mongrel2libdir = mongrel2dir + 'lib'

	$LOAD_PATH.unshift( strelkalibdir.to_s ) unless $LOAD_PATH.include?( strelkalibdir.to_s )
	$LOAD_PATH.unshift( mongrel2libdir.to_s ) unless $LOAD_PATH.include?( mongrel2libdir.to_s )
}

# SimpleCov test coverage reporting; enable this using the :coverage rake task
require 'simplecov' if ENV['COVERAGE']

require 'stringio'
require 'time'


require 'loggability'
require 'loggability/spechelpers'
require 'configurability'
require 'configurability/behavior'

require 'rspec'
require 'mongrel2'
require 'mongrel2/testing'

require 'strelka'
require 'strelka/testing'
require 'strelka/authprovider'

require 'thingfish'
require 'thingfish/spechelpers'


Loggability.format_with( :color ) if $stdout.tty?


### Mock with RSpec
RSpec.configure do |config|
	include Strelka::Constants
	include Thingfish::SpecHelpers
	include Thingfish::SpecHelpers::Constants

	config.mock_with( :rspec ) do |mock|
		mock.syntax = :expect
	end

	config.disable_monkey_patching!
	config.example_status_persistence_file_path = "spec/.status"
	config.filter_run :focus
	config.filter_run_when_matching :focus
	config.order = :random
	config.profile_examples = 5
	config.run_all_when_everything_filtered = true
	config.shared_context_metadata_behavior = :apply_to_host_groups
	# config.warnings = true

	config.include( Loggability::SpecHelpers )
	config.include( Mongrel2::SpecHelpers )
	config.include( Mongrel2::Constants )
	config.include( Mongrel2::Config::DSL )
	config.include( Strelka::Constants )
	config.include( Strelka::Testing )
	config.include( Thingfish::SpecHelpers )
end

# vim: set nosta noet ts=4 sw=4:

