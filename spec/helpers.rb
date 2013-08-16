#!/usr/bin/ruby
# coding: utf-8

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	srcdir = basedir.parent
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir.to_s ) unless $LOAD_PATH.include?( basedir.to_s )
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
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
	TEST_APPID        = 'thingfish-test'
	TEST_SEND_SPEC    = 'tcp://127.0.0.1:9999'
	TEST_RECV_SPEC    = 'tcp://127.0.0.1:9998'

	UUID_PATTERN      = /(?<uuid>[[:xdigit:]]{8}(?:-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12})/i

	TEST_UUID         = 'E5DFEEAB-3525-4F14-B4DB-2772D0B9987F'

	TEST_TEXT_DATA    = "Pork sausage. Pork! Sausage!"
	TEST_TEXT_DATA_IO = StringIO.new( TEST_TEXT_DATA )
	TEST_PNG_DATA     = ("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMA" +
	                     "AQAABQABDQottAAAAABJRU5ErkJggg==").unpack('m').first
	TEST_PNG_DATA_IO  = StringIO.new( TEST_PNG_DATA )


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

