#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/processor'

require 'strelka/httprequest/metadata'


describe Thingfish::Processor, "SHA256" do

	before( :all ) do
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Metadata }
	end


	let( :processor ) { described_class.create(:sha256) }

	let( :factory ) do
		Mongrel2::RequestFactory.new(
			:route => '/',
			:headers => {:accept => '*/*'})
	end


	it "generates a sha256 checksum from an uploaded file" do
		req = factory.post( '/tf', fixture_data('APIC-1-image.mp3'), 'Content-type' => 'audio/mp3' )

		processor.process_request( req )

		expect( req.metadata['checksum'] ).to eq( 'e6b7070cbec90cdc2d8206819d86d100f076f480c9ae19d3eb8f878b3b86f2d6' )
	end
end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
