#!/usr/bin/env ruby

require_relative '../helpers'

require 'rspec'
require 'thingfish/processor'


describe Thingfish::Processor do

	before( :all ) do
		setup_logging()
	end


	it "has pluggability" do
		expect( described_class.plugin_type ).to eq( 'Processor' )
	end


	it "defines a (no-op) method for handling requests" do
		expect {
			described_class.new.on_request( nil )
		}.to_not raise_error
	end


	it "defines a (no-op) method for handling responses" do
		expect {
			described_class.new.on_response( nil )
		}.to_not raise_error
	end


	describe "a subclass" do

		let!( :subclass ) { Class.new(described_class) }

		it "can declare a list of media types it handles" do
			subclass.handled_types( 'image/*', 'video/*' )
			expect( subclass.handled_types.size ).to be( 2 )
			expect( subclass.handled_types[0] ).to be_a( Strelka::HTTPRequest::MediaType )
		end

		describe "instance" do

			let!( :instance ) do
				subclass.handled_types( 'audio/mpeg', 'audio/mpg', 'audio/mp3' )
				subclass.new
			end


			it "knows that it doesn't handle a type it hasn't registered" do
				expect( instance ).to_not be_handled_type( 'image/png' )
				expect( instance ).to be_handled_type( 'audio/mp3' )
			end


		end

	end

end

# vim: set nosta noet ts=4 sw=4 ft=rspec:
