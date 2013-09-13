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
if ENV['COVERAGE']
	$stderr.puts "\n\n>>> Enabling coverage report.\n\n"
	require 'simplecov'
	SimpleCov.start do
		add_filter 'spec'
		add_group "Needing tests" do |file|
			file.covered_percent < 90
		end
	end
end

require_relative 'constants'

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

Loggability.format_with( :color ) if $stdout.tty?


### RSpec helper functions.
module Thingfish::SpecHelpers
	include Thingfish::SpecConstants

	RSpec::Matchers.define :be_a_uuid do |expected|
		match do |actual|
			actual =~ UUID_PATTERN
		end
	end

end


### Mock with RSpec
RSpec.configure do |c|
	include Strelka::Constants
	include Thingfish::SpecHelpers

	c.treat_symbols_as_metadata_keys_with_true_values = true
	c.mock_with( :rspec ) do |config|
		config.syntax = :expect
	end

	c.include( Loggability::SpecHelpers )
	c.include( Mongrel2::SpecHelpers )
	c.include( Mongrel2::Constants )
	c.include( Strelka::Constants )
	c.include( Strelka::Testing )
	c.include( Thingfish::SpecHelpers )
end

# vim: set nosta noet ts=4 sw=4:

