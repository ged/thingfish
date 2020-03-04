#!/usr/bin/env rspec -cfd -b
# vim: set noet nosta sw=4 ts=4 :

require_relative '../helpers'

require 'rspec'

require 'thingfish/mixins'


RSpec.describe Thingfish, 'mixins' do

	# A collection of functions for dealing with object IDs.
	describe 'Normalization' do

		it 'can generate a new object ID' do
			expect( Thingfish::Normalization.make_object_id ).to match( UUID_PATTERN )
		end

		it 'can normalize an object ID' do
			expect(
				Thingfish::Normalization.normalize_oid( TEST_UUID.upcase )
			).to_not match( /[A-Z]/ )
		end

		it 'can normalize Hash metadata keys' do
			metadata = { :pork => 1, :sausaged => 2 }
			expect( Thingfish::Normalization.normalize_keys(metadata) ).
				to eq({ 'pork' => 1, 'sausaged' => 2 })
		end

		it 'can normalize an Array of metadata keys' do
			values = [ :pork, :sausaged ]
			expect( Thingfish::Normalization.normalize_keys(values) ).
				to eq([ 'pork', 'sausaged' ])
			expect( values.first ).to be( :pork )
		end

		it "won't modify the original array of metadata keys" do
			values = [ :pork, :sausaged ]
			normalized = Thingfish::Normalization.normalize_keys( values )

			expect( values.first ).to be( :pork )
			expect( normalized ).to_not be( values )
		end

		it "replaces non metadata key characters with underscores" do
			expect( Thingfish::Normalization::normalize_key('Sausaged!') ).to eq( 'sausaged_' )
			expect( Thingfish::Normalization::normalize_key('SO sausaged') ).to eq( 'so_sausaged' )
			expect( Thingfish::Normalization::normalize_key('*/porky+-') ).to eq( '_porky_' )
		end

		it "preserves colons in metadata keys" do
			expect( Thingfish::Normalization::normalize_key('pork:sausaged') ).
				to eq( 'pork:sausaged' )
		end


	end # module Normalization


end

