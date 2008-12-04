#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'thingfish'
	require 'thingfish/filestore'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


class TestFileStore < ThingFish::FileStore
end


#####################################################################
###	C O N T E X T S
#####################################################################

describe "An instance of a derivative filestore class" do

	before(:each) do
		@filestore = ThingFish::FileStore.create( 'test', nil, nil )
	end

	it "knows how to perform startup tasks" do
		@filestore.should respond_to( :on_startup )
	end

	### Required derivative daemon interface specs

	it "raises a NotImplementedError for write operations" do
		lambda do
			@filestore.store( :key, :value )
		end.should raise_error( NotImplementedError, /#store/i)
	end

	it "raises a NotImplementedError for read operations" do
		lambda do
			@filestore.fetch( :key )
		end.should raise_error( NotImplementedError, /#fetch/i)
	end

	it "raises a NotImplementedError for delete operations" do
		lambda do
			@filestore.delete( :key )
		end.should raise_error( NotImplementedError, /#delete/i)
	end

	it "raises a NotImplementedError for size checks" do
		lambda do
			@filestore.size( :key )
		end.should raise_error( NotImplementedError, /#size/i)
	end

	it "raises a NotImplementedError for file presence checks" do
		lambda do
			@filestore.has_file?( :key )
		end.should raise_error( NotImplementedError, /#has_file\?/i)
	end


	### Admin API specs
	it "raises a NotImplementedError for filestore total size diagnostic" do
		lambda do
			@filestore.total_size
		end.should raise_error( NotImplementedError, /#total_size/i)
	end
end


describe "The base filestore class" do

	it "registers subclasses as plugins" do
		ThingFish::FileStore.get_subclass( 'test' ).should == TestFileStore
	end

end

