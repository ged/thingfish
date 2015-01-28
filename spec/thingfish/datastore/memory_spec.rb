#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/datastore'
require 'thingfish/behaviors'


describe Thingfish::Datastore, "memory" do

	let( :store ) { Thingfish::Datastore.create(:memory) }


	it_behaves_like "a Thingfish datastore"

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
