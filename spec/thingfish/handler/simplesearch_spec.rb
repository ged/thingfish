#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

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
	require 'thingfish/handler/simplesearch'
	require 'thingfish/metastore/simple'
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

describe ThingFish::SimpleSearchHandler do

	before( :all ) do
		setup_logging( :fatal )
	end
	
	after( :all ) do
		reset_logging()
	end
	
	before( :each ) do
		resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent.parent + 'var/www'

		options = { :resource_dir => resdir }

		@handler   = ThingFish::SimpleSearchHandler.new( '/search', options )
		@request   = mock( "request" )
		@response  = mock( "response" )
		@headers   = mock( "headers" )
		@daemon    = mock( "daemon" )
		@metastore = mock( "metastore" )

		@uri = URI.parse( 'http://localhost:3474/search' )
		@request.stub!( :uri ).and_return( @uri )
		@config = ThingFish::Config.new

		@response.stub!( :headers ).and_return( @headers )
	end


	describe " set up with a simple metastore" do

		before(:each) do
			@daemon.stub!( :metastore ).and_return( @metastore )
			@daemon.stub!( :filestore ).and_return( :filestore )
			@daemon.stub!( :config ).and_return( @config )
			urimap = stub( "urimap", :register_first => nil )
			@daemon.stub!( :urimap ).and_return( urimap )

			@handler.on_startup( @daemon )
		end


		# Shared behaviors
		it_should_behave_like "A Handler"

		# Examples

		it "finds resources with equality matching on a single key" do
			search_terms = {
				'namespace' => 'bangry'
			}

			@request.should_receive( :query_args ).
				at_least(:once).
				and_return( search_terms )
			@metastore.should_receive( :find_by_matching_properties ).
				with( search_terms ).
				and_return([ TEST_UUID ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID ])

			@handler.handle_get_request( '', @request, @response )
		end

		it "finds resources with equality matching multiple keys ANDed together" do
			search_terms = {
				'namespace' => 'summer',
				'filename'  => '2-proof.jpg'
			}

			@request.should_receive( :query_args ).
				at_least(:once).
				and_return( search_terms )
			@metastore.should_receive( :find_by_matching_properties ).
				with( search_terms ).
				and_return([ TEST_UUID, TEST_UUID2 ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID, TEST_UUID2 ])

			@handler.handle_get_request( '', @request, @response )
		end

		it "can build an HTML fragment for the HTML filter" do
			erb_template = ERB.new( "A template that refers to <%= uri %>" )
			@handler.stub!( :get_erb_resource ).and_return( erb_template )

			html = @handler.make_index_content( "/uri" )
			html.should == "A template that refers to /uri"
		end


		it "can build an HTML fragment for the index page" do
			erb_template = ERB.new(
				"Some template that refers to <%= uuids %>, <%= args %>, and <%= uri %>"
			  )

			@request.should_receive( :query_args ).and_return( "args" )
			@request.should_receive( :uri ).and_return( stub("fake uri", :path => 'uripath') )
			@response.should_receive( :data ).at_least( :once ).and_return( {} )

			@handler.stub!( :get_erb_resource ).and_return( erb_template )
			@handler.make_html_content( "uuids", @request, @response ).
				should == "Some template that refers to uuids, args, and uripath"
		end
	end


end

