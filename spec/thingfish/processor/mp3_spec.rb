#!/usr/bin/env ruby

require_relative '../../helpers'

require 'rspec'
require 'thingfish/processor'

require 'strelka/httprequest/metadata'


describe Thingfish::Processor, "MP3" do

	before( :all ) do
		Strelka::HTTPRequest.class_eval { include Strelka::HTTPRequest::Metadata }
	end


	let( :processor ) { described_class.create(:mp3) }

	let( :factory ) do
		Mongrel2::RequestFactory.new(
			:route => '/',
			:headers => {:accept => '*/*'})
	end


	it "extracts metadata from uploaded MP3 ID3 tags" do
		req = factory.post( '/tf', fixture_data('APIC-1-image.mp3'), 'Content-type' => 'audio/mp3' )

		processor.process_request( req )

		expect( req.metadata ).to include( 'mp3:artist', 'mp3:bitrate', 'mp3:comments' )
	end


	it "attaches album art as a related resource" do
		req = factory.post( '/tf', fixture_data('APIC-1-image.mp3'), 'Content-type' => 'audio/mp3' )

		processor.process_request( req )

		related = req.related_resources
		expect( related.size ).to eq( 1 )
		expect( related.values.first ).
			to include( 'format' => 'image/jpeg', 'extent' => 7369, 'relationship' => 'album-art' )
		expect( related.keys.first ).to respond_to( :read )
	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
