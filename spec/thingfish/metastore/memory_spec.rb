#!/usr/bin/env ruby

require_relative '../../helpers'

require 'securerandom'
require 'rspec'
require 'thingfish/metastore/memory'
require 'thingfish/behaviors'


RSpec.describe Thingfish::Metastore::Memory do

	it_behaves_like "a Thingfish metastore"

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
