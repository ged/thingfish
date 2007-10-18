#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/handler_behavior'
	require 'time'

	require 'thingfish'
	require 'thingfish/handler/search'
	require 'thingfish/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


include ThingFish::Constants
include ThingFish::TestConstants

#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::SearchHandler do
	
	before(:each) do
		# ThingFish.logger.level = Logger::DEBUG
		ThingFish.logger.level = Logger::FATAL
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'var/www'
		
		options = {
			:uris         => ['/search'],
			:resource_dir => resdir
		}

		@handler   = ThingFish::SearchHandler.new( options )
		@request   = mock( "request", :null_object => true )
		@response  = mock( "response", :null_object => true )
		@headers   = mock( "headers", :null_object => true )
		@listener  = mock( "listener", :null_object => true )
		@metastore = mock( "metastore", :null_object => true )
		
		@response.stub!( :headers ).and_return( @headers )
		@listener.stub!( :metastore ).and_return( @metastore )

		@handler.listener = @listener
	end


	# Shared behaviors
	it_should_behave_like "A Handler"
	
	# Examples

	it "finds resources with equality matching on a single key (HTML accept)" do
		search_terms = {
			'namespace' => 'bangry'
		}
		
		@request.should_receive( :query_args ).
			at_least(:once).
			and_return( search_terms )
		@metastore.should_receive( :find_by_exact_properties ).
			with( search_terms ).
			and_return([ TEST_UUID ])
		
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( true )

		@headers.should_receive( :[]= ).with( :content_type, 'text/html' )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with( /<html/i )
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "finds resources with equality matching on a single key" do
		search_terms = {
			'namespace' => 'bangry'
		}
		
		@request.should_receive( :query_args ).
			at_least(:once).
			and_return( search_terms )
		@metastore.should_receive( :find_by_exact_properties ).
			with( search_terms ).
			and_return([ TEST_UUID ])
		
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with([ TEST_UUID ])
		
		@handler.handle_get_request( @request, @response )
	end
	
	it "finds resources with equality matching multiple keys ANDed together" do
		search_terms = {
			'namespace' => 'summer',
			'filename'  => '2-proof.jpg'
		}
		
		@request.should_receive( :query_args ).
			at_least(:once).
			and_return( search_terms )
		@metastore.should_receive( :find_by_exact_properties ).
			with( search_terms ).
			and_return([ TEST_UUID, TEST_UUID2 ])
		
		@request.should_receive( :accepts? ).
			with( 'text/html' ).
			and_return( false )

		@headers.should_receive( :[]= ).with( :content_type, RUBY_MIMETYPE )
		@response.should_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :body= ).with([ TEST_UUID, TEST_UUID2 ])
		
		@handler.handle_get_request( @request, @response )
	end

end

