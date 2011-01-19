#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( basedir ) unless $LOAD_PATH.include?( basedir )
	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

require 'rspec'

require 'spec/lib/helpers'

require 'thingfish'
require 'thingfish/handler/simplesearch'
require 'thingfish/metastore/simple'
require 'thingfish/behavior/handler'


#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::SimpleSearchHandler do

	DEFAULT_ORDER = []
	DEFAULT_OFFSET = 0

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :handler ) do
		resdir = Pathname.new( __FILE__ ).expand_path.
			dirname.parent.parent + 'data/thingfish/web-interface'
		options = { :resource_dir => resdir }
		ThingFish::SimpleSearchHandler.new( '/search', options )
	end

	before( :each ) do
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

	after( :all ) do
		reset_logging()
	end


	describe " set up with a simple metastore" do

		before(:each) do
			@daemon.stub!( :metastore ).and_return( @metastore )
			@daemon.stub!( :filestore ).and_return( :filestore )
			@daemon.stub!( :config ).and_return( @config )
			urimap = stub( "urimap", :register_first => nil )
			@daemon.stub!( :urimap ).and_return( urimap )

			self.handler.on_startup( @daemon )
		end


		# Shared behaviors
		it_should_behave_like "a handler"

		# Examples

		it "finds the UUID of resources with equality matching on a single key" do
			search_terms = {
				'namespace' => 'bangry'
			}

			@request.should_receive( :query_args ).at_least( :once ).and_return({})
			@metastore.should_receive( :find_by_exact_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ [TEST_UUID, :a_properties_hash] ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID ])

			self.handler.handle_get_request( 'namespace=bangry', @request, @response )
		end


		it "unescapes URI-escaped characters in search terms" do
			search_terms = {
				'path' => 'production/kate&nate/frame002_177.mov'
			}

			@request.should_receive( :query_args ).at_least( :once ).and_return({})
			@metastore.should_receive( :find_by_exact_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ [TEST_UUID, :a_properties_hash] ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID ])

			self.handler.handle_get_request( 'path=production%2Fkate%26nate%2Fframe002_177.mov',
			 	@request, @response )
		end


		it "returns a bad request response if there is extraneous path info (additional slashes)" do
			@metastore.should_not_receive( :find_by_matching_properties )

			expect {
				self.handler.handle_get_request( 'key=/unescaped/path', @request, @response )
			}.to raise_error( ThingFish::RequestError, /extraneous path info/i )
		end


		it "finds all properties of resources with equality matching on a single key" do
			search_terms = {
				'namespace' => 'bangry'
			}

			@request.should_receive( :query_args ).at_least( :once ).
				and_return({ 'full' => nil })
			@metastore.should_receive( :find_by_exact_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ TEST_UUID, :a_properties_hash ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID, :a_properties_hash ])

			self.handler.handle_get_request( 'namespace=bangry', @request, @response )
		end

		it "finds resource UUIDs with equality matching multiple keys ANDed together" do
			search_terms = {
				'namespace' => 'summer',
				'filename'  => '2-proof.jpg'
			}

			@request.should_receive( :query_args ).
				at_least(:once).
				and_return( search_terms )
			@metastore.should_receive( :find_by_exact_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ [TEST_UUID, :a_properties_hash], [TEST_UUID2, :a_second_properties_hash] ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID, TEST_UUID2 ])

			self.handler.handle_get_request( 'namespace=summer;filename=2-proof.jpg', @request, @response )
		end

		it "finds all resource properties with equality matching multiple keys ANDed together" do
			search_terms = {
				'namespace' => 'summer',
				'filename'  => '2-proof.jpg'
			}

			@request.should_receive( :query_args ).at_least(:once).
				and_return({ 'full' => '1' })
			@metastore.should_receive( :find_by_exact_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ [TEST_UUID, :a_properties_hash], [TEST_UUID2, :a_second_properties_hash] ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([
				[TEST_UUID,   :a_properties_hash],
				[TEST_UUID2,  :a_second_properties_hash],
			])

			self.handler.handle_get_request( 'namespace=summer;filename=2-proof.jpg', @request, @response )
		end


		it "uses metastore string matching interface for a wildcard term" do
			search_terms = { 'weapon' => 'crepe*' }

			@request.should_receive( :query_args ).at_least( :once ).
				and_return({ 'full' => nil })
			@metastore.should_receive( :find_by_matching_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ TEST_UUID, :a_properties_hash ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID, :a_properties_hash ])

			self.handler.handle_get_request( 'weapon=crepe*', @request, @response )
		end


		it "uses metastore string matching interface if any terms contain wildcards" do
			search_terms = {
				'weapon' => 'crepe*',
				'target' => 'vehicle'
			}

			@request.should_receive( :query_args ).at_least( :once ).
				and_return({ 'full' => nil })
			@metastore.should_receive( :find_by_matching_properties ).
				with( search_terms, DEFAULT_ORDER, DEFAULT_LIMIT, DEFAULT_OFFSET ).
				and_return([ TEST_UUID, :a_properties_hash ])

			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :body= ).with([ TEST_UUID, :a_properties_hash ])

			self.handler.handle_get_request( 'weapon=crepe*;target=vehicle', @request, @response )
		end


		it "can build an HTML fragment for the HTML filter" do
			erb_template = ERB.new( "A template that refers to <%= uri %>" )
			self.handler.stub!( :get_erb_resource ).and_return( erb_template )

			html = self.handler.make_index_content( "/uri" )
			html.should == "A template that refers to /uri"
		end


		it "can build an HTML fragment for the index page" do
			erb_template = ERB.new(
				"Some template that refers to <%= uuids %>, <%= args %>, and <%= uri %>"
			  )

			@request.should_receive( :query_args ).and_return( "args" )
			@request.should_receive( :uri ).and_return( stub("fake uri", :path => 'uripath') )
			@response.should_receive( :data ).at_least( :once ).and_return( {} )

			self.handler.stub!( :get_erb_resource ).and_return( erb_template )
			self.handler.make_html_content( "uuids", @request, @response ).
				should == "Some template that refers to uuids, args, and uripath"
		end

	end


end

