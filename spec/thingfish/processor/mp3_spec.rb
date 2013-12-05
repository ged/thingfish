#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/processor'


describe Thingfish::Processor, "MP3" do

	let( :factory ) do
		Mongrel2::RequestFactory.new(
			:route => '/',
			:headers => {:accept => '*/*'})
	end


	it "extracts metadata from uploaded MP3 ID3 tags"

	it "attaches album art as a related resource"


end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
