#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/filestore'


class TestFileStore < ThingFish::FileStore
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::FileStore do

	it "registers subclasses as plugins" do
		described_class.get_subclass( 'test' ).should == TestFileStore
	end


	context "a concrete subclass with no method overrides" do

		before( :each ) do
			@filestore = ThingFish::FileStore.create( 'test', nil, nil )
		end

		it "doesn't raise an exception when told to perform startup tasks" do
			expect {
				@filestore.on_startup
			}.to_not raise_error()
		end

		### Required derivative daemon interface specs

		it "raises a NotImplementedError for write operations" do
			expect {
				@filestore.store( :key, :value )
			}.to raise_error( NotImplementedError, /#store/i)
		end

		it "raises a NotImplementedError for read operations" do
			expect {
				@filestore.fetch( :key )
			}.to raise_error( NotImplementedError, /#fetch/i)
		end

		it "raises a NotImplementedError for delete operations" do
			expect {
				@filestore.delete( :key )
			}.to raise_error( NotImplementedError, /#delete/i)
		end

		it "raises a NotImplementedError for size checks" do
			expect {
				@filestore.size( :key )
			}.to raise_error( NotImplementedError, /#size/i)
		end

		it "raises a NotImplementedError for file presence checks" do
			expect {
				@filestore.has_file?( :key )
			}.to raise_error( NotImplementedError, /#has_file\?/i)
		end


		### Admin API specs
		it "raises a NotImplementedError for filestore total size diagnostic" do
			expect {
				@filestore.total_size
			}.to raise_error( NotImplementedError, /#total_size/i)
		end

	end

end

