#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

require 'rspec'
require 'spec/lib/helpers'
require 'spec/lib/filter_behavior'

require 'rbconfig'
require 'ipaddr'

require 'thingfish'
require 'thingfish/filter'

begin
	require 'thingfish/filter/xml'
	$clxmlserial_loaderror = nil
rescue LoadError => err
	$clxmlserial_loaderror = err
	class ThingFish::XMLFilter; end
end



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::XMLFilter do

	before( :each ) do
		if $clxmlserial_loaderror
			pending "installation of the cl/xmlserial library (%s)" %
				[ $clxmlserial_loaderror.message ]
		end
	end

	describe Symbol, " with XMLFilter extensions" do
		it "is XMLSerializable" do
			:blah.to_xml.to_s.should =~ /<Symbol>/
		end
	end

	describe IPAddr, " with XMLFilter extensions" do
		it "is XMLSerializable" do
			IPAddr.new('127.0.0.1').to_xml.to_s.should =~ /<IPAddr>127/
		end
	end


	unless $clxmlserial_loaderror
		TEST_XML_CONTENT = TEST_RUBY_OBJECT.to_xml

		# Switch the 'make_xml' method to public for testing.
		class ThingFish::XMLFilter
			public :make_xml
		end
	end


	describe " with Tidy disabled" do

		before( :all ) do
			ThingFish.reset_logger
			ThingFish.logger.level = Logger::FATAL
		end

		before( :each ) do
			@filter = ThingFish::Filter.create( 'xml' )

			@request = mock( "request object" )
			@response = mock( "response object" )
			@response_headers = mock( "response headers" )
			@response.stub!( :headers ).and_return( @response_headers )
		end

		after( :all ) do
			ThingFish.reset_logger
		end


		it_should_behave_like "a filter"


		it "converts Ruby-object responses to XML if the client accepts it" do
			@ruby_obj = mock( "a ruby data structure" )

			@request.should_receive( :explicitly_accepts? ).
				with( 'application/xml' ).
				and_return( true )
			@response.should_receive( :content_type ).
				at_least( :once ).
				and_return( RUBY_MIMETYPE )

			@response.should_receive( :body ).
				at_least( :once ).
				and_return( @ruby_obj )
			@ruby_obj.should_receive( :to_xml ).
				and_return( TEST_XML_CONTENT )

			@response.should_receive( :body= ).with( TEST_XML_CONTENT )
			@response.should_not_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :content_type= ).with( 'application/xml' )

			@filter.handle_response( @response, @request )
		end


		it "does no conversion if the client doesn't accept XML" do
			@request.should_receive( :explicitly_accepts? ).
				with( 'application/xml' ).
				and_return( false )

			@response.should_not_receive( :body= )
			@response.should_not_receive( :status= )
			@response.should_not_receive( :content_type= )

			@filter.handle_response( @response, @request )
		end


		it "does no conversion if the response isn't a Ruby object" do
			@request.should_receive( :explicitly_accepts? ).
				with( 'application/xml' ).
				and_return( true )
			@response.should_receive( :content_type ).
				at_least( :once ).
				and_return( ThingFish.configured_html_mimetype )

			@response.should_not_receive( :body= )
			@response.should_not_receive( :status= )
			@response.should_not_receive( :content_type= )

			@filter.handle_response( @response, @request )
		end


		it "propagates errors during XML generation" do
			@request.should_receive( :explicitly_accepts? ).
				with( 'application/xml' ).
				and_return( true )
			@response.should_receive( :content_type ).
				at_least( :once ).
				and_return( RUBY_MIMETYPE )

			erroring_object = mock( "ruby object that raises an error when converted to XML" )
			@response.should_receive( :body ).
				at_least( :once ).
				and_return( erroring_object )

			erroring_object.should_receive( :to_xml ).
				and_raise( "Oops, couldn't convert to XML for some reason!" )

			@response.should_not_receive( :body= )
			@response.should_not_receive( :status= )
			@response.should_not_receive( :content_type= )

			lambda {
				@filter.handle_response( @response, @request )
			}.should raise_error()
		end
	end

	# Fake a Tidy class if none is loaded
	if !defined?( Tidy )
		module Tidy; end
	end

	describe " with Tidy enabled" do

		before( :all ) do
			ThingFish.reset_logger
			ThingFish.logger.level = Logger::FATAL
		end

		before( :each ) do
			pending "example doesn't work under 1.9.1" if RUBY_VERSION >= '1.9.1'
		end


		after( :all ) do
			ThingFish.reset_logger
		end


		# Examples

		it "doesn't die if Tidy can't be loaded" do
			Kernel.stub!( :require ).and_raise( LoadError.new("no such file to load -- tidy") )

			lambda {
				ThingFish::Filter.create( 'xml', 'use_tidy' => true )
			}.should_not raise_error()
		end


		it "doesn't die if the tidy shared library can't be found" do

			ThingFish::XMLFilter.stub!( :require ).and_return( true )

			lambda {
				ThingFish::Filter.create( 'xml',
					'usetidy' => true,
					'tidypath' => '/someplace/nonexistant' )
			}.should_not raise_error()
		end


		it "cleans up XML output if Tidy loaded successfully" do
			# Simulate tidy having loaded successfully
			$" << "tidy.rb"

			request = mock( "request object" )
			response = mock( "response object" )
			response_headers = mock( "response headers" )
			response.stub!( :headers ).and_return( @response_headers )

			Kernel.stub!( :require ).and_return( true )
			File.should_receive( :exist? ).with( '/fakepath' ).and_return( true )
			Tidy.should_receive( :path= ).with( '/fakepath' )
			tidy = mock( "A Tidy object" ).as_null_object
			tidyoptions = stub( 'Tidy option object',
							   :output_xml= => true,
							   :input_xml=  => true,
							   :indent=     => true )

			filter = ThingFish::Filter.create( 'xml',
				'usetidy' => true,
				'tidypath' => '/fakepath' )

			Tidy.should_receive( :open ).and_yield( tidy )

			body = mock( "Body content" ).as_null_object
			body.should_receive( :to_xml ).and_return( :xml )
			tidy.should_receive( :options ).at_least( :once ).and_return( tidyoptions )
			tidy.should_receive( :clean ).with( :xml ).and_return( :clean_xml )

			filter.make_xml( body )
		end

	end

end

# vim: set nosta noet ts=4 sw=4:

