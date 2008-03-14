#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	plugindir = Pathname.new( __FILE__ ).dirname.parent.parent.parent
	basedir = plugindir.parent.parent

	libdir = basedir + "lib"
	pluglibdir = plugindir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
	$LOAD_PATH.unshift( pluglibdir ) unless $LOAD_PATH.include?( pluglibdir )
}

begin
	require 'pathname'
	require 'stringio'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'spec/lib/helpers'
	require 'spec/lib/handler_behavior'

	require 'thingfish/constants'
	require 'thingfish/handler/status'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end




#####################################################################
###	C O N T E X T S
#####################################################################

describe ThingFish::StatusHandler do

	include ThingFish::Constants,
			ThingFish::TestConstants,
			ThingFish::SpecHelpers


	before( :all ) do
		setup_logging( :fatal )
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	describe " with no stats filters" do
		before( :each ) do
			@request          = mock( "request", :null_object => true )
			@response         = mock( "response", :null_object => true )
			@listener         = mock( "listener", :null_object => true )

			@response_headers = mock( "response headers", :null_object => true )
			@response.stub!( :headers ).and_return( @response_headers )
			@request_headers = mock( "request headers", :null_object => true )
			@request.stub!( :headers ).and_return( @request_headers )

			resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
		    @handler  = ThingFish::Handler.create( 'status', 'resource_dir' => resdir )
		end


		### Specs

		it "doesn't register any filters with its listener" do
			classifier = Mongrel::URIClassifier.new
			classifier.register( '/status', @handler )

			@listener.should_receive( :classifier ).at_least(1).and_return( classifier )
			@listener.should_receive( :register ).once

			@handler.listener = @listener
		end


		it "responds with a data structure describing the statistics gathered so far" do
			filter = mock( "a filter" )
			stat   = mock( "a Mongrel::Stats object", :null_object => true )

			classifier = Mongrel::URIClassifier.new
			classifier.register( '/status', [filter, @handler] )
			classifier.register( '/no-stats', [@handler] )
			@listener.should_receive( :classifier ).at_least(1).and_return( classifier )
			@handler.listener = @listener
			@handler.filters[ '/status' ] = filter
	
			filter.should_receive( :each_stat ).and_yield( stat )
			stat.should_receive( :name ).at_least( :once ).and_return('porkenheimer')
				
			@response.should_receive( :status= ).with( HTTP::OK )
			@response.should_receive( :content_type= ).with( RUBY_MIMETYPE )
			@response.should_receive( :body= ).with( an_instance_of(Hash) )

			@handler.handle_get_request( @request, @response )
		end


		it "can build an HTML fragment for the HTML filter" do
			erb_template = ERB.new( "A template that refers to <%= body %>" )
			@handler.stub!( :get_erb_resource ).and_return( erb_template )
		
			html = @handler.make_html_content( "the body", @request, @response )
			html.should == "A template that refers to the body"
		end


		it "can build an HTML fragment for the index page" do
			erb_template = ERB.new( "Some template that refers to <%= uri %>" )
			@handler.stub!( :get_erb_resource ).and_return( erb_template )
			@handler.make_index_content( "/foo" ).should ==
				"Some template that refers to /foo"
		end
	end


	describe " with stats filters" do
		before(:each) do
			resdir = Pathname.new( __FILE__ ).expand_path.dirname.parent + 'resources'
			options = {
				'resource_dir' => resdir,
				'stat_uris' => %w[/ /metadata /admin],
			}
		
			@listener = mock( "listener", :null_object => true )
		    @handler  = ThingFish::Handler.create( 'status', options )
		end

		it "registers a StatisticsFilter with its listener for each configured URI" do
			@listener.
				should_receive( :register ).
				with( an_instance_of(String), duck_type(:process, :dump), true ).
				exactly(3).times
		
			@handler.listener = @listener
		end
	
	end

end




describe Mongrel::StatisticsFilter, " (monkeypatched)" do
	
	before(:all) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end

	after(:all) do
		ThingFish.reset_logger
	end


	before( :each ) do
		@filter = Mongrel::StatisticsFilter.new( :sample_rate => 1 )
	end
	
	
	it "has an iterator that yields each stat" do
		@filter.each_stat do |stat|
			stat.should be_an_instance_of( Mongrel::Stats )
		end
	end


	it "gathers statistcs from the ThingFish request and response objects " +
		"instead of the Mongrel ones" do
		
		request = mock( "request object" )
		request_headers = mock( "request headers" )
		response = mock( "response object" )
		response_headers = mock( "response headers" )
		daemon = mock( "daemon object" )
		workers = mock( "listener thread group" )
		
		
		@filter.listener = daemon
		daemon.should_receive( :workers ).and_return( workers )
		workers.should_receive( :list ).and_return( [1,2,3,4,5,6,7] )

		request.should_receive( :uri ).
			any_number_of_times.
			and_return( URI.parse('http://localhost:3474/pork') )
		request.should_receive( :headers ).
			at_least(:once).
			and_return( request_headers )
		request_headers.
			should_receive( :length ).
			and_return( 91752636 )

		request.should_receive( :body ).
			and_return( TEST_CONTENT )

		response.should_receive( :get_content_length ).
			and_return( 100 )
		response.should_receive( :headers ).
			at_least(:once).
			and_return( response_headers )
		response_headers.
			should_receive( :to_s ).
			and_return( "stringified headers" )
		
		@filter.process( request, response )
	end
	
end


# vim: set nosta noet ts=4 sw=4:
