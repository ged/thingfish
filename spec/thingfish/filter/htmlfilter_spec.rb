#!/usr/bin/env ruby

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent.parent

	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir ) unless $LOAD_PATH.include?( libdir )
}

begin
	require 'rbconfig'
	require 'spec/runner'
	require 'spec/lib/constants'
	require 'thingfish'
	require 'thingfish/filter'
	require 'thingfish/filter/html'
	require 'spec/lib/filter_behavior'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::HtmlFilter do
	
	before( :all ) do
		ThingFish.reset_logger
		ThingFish.logger.level = Logger::FATAL
	end
		
	before( :each ) do
		@filter = ThingFish::Filter.create( 'html', {} )

		@request = mock( "request object" )
		@response = mock( "response object" )

		@response_headers = mock( "response headers" )
		@response.stub!( :headers ).and_return( @response_headers )

		@first_handler = mock( "first handler" )
		@middle_handler = mock( "middle handler" )
		@last_handler = mock( "last handler" )
		@response.stub!( :handlers ).and_return([ @first_handler, @middle_handler, @last_handler ])
	end

	after( :all ) do
		ThingFish.reset_logger
	end


	it_should_behave_like "A Filter"

	
	it "uses handler HTML API to convert Ruby-object responses to HTML if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( XHTML_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		body = mock( "response body" )
		@response.should_receive( :body ).twice.and_return( body )

		@first_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( true )
		@middle_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( false )
		@last_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( true )

		@first_handler.should_receive( :make_html_content ).
			with( body, @request, @response ).
			and_return( 'first_html' )
		@middle_handler.should_not_receive( :make_html_content )
		@last_handler.should_receive( :make_html_content ).
			with( body, @request, @response ).
			and_return( 'last_html' )

		erbtemplate = mock( "ERB wrapper template", :null_object => true )
		@filter.stub!( :get_erb_resource ).and_return( erbtemplate )
		erbtemplate.should_receive( :result ).
			with( an_instance_of(Binding) ).
			and_return( :wrapped_html_content )

		@response.should_receive( :body= ).with( :wrapped_html_content )
		# Transform filters shouldn't change the status of the response
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( XHTML_MIMETYPE )
		
		@filter.handle_response( @response, @request )
	end


	it "uses the HtmlInspectableObject interface to convert responses to HTML if none of " +
	   "the handlers implements the HTML filter API" do
		@request.should_receive( :explicitly_accepts? ).
			with( XHTML_MIMETYPE ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		body = mock( "response body" )
		@response.should_receive( :body ).at_least( :once ).and_return( body )

		@first_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( false )
		@middle_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( false )
		@last_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( false )

		@first_handler.should_not_receive( :make_html_content )
		@middle_handler.should_not_receive( :make_html_content )
		@last_handler.should_not_receive( :make_html_content )

		body.should_receive( :html_inspect ).and_return( "some html" )
		
		erbtemplate = mock( "ERB wrapper template", :null_object => true )
		@filter.stub!( :get_erb_resource ).and_return( erbtemplate )
		erbtemplate.should_receive( :result ).
			with( an_instance_of(Binding) ).
			and_return( :wrapped_html_content )

		@response.should_receive( :body= ).with( :wrapped_html_content )
		# Transform filters shouldn't change the status of the response
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( XHTML_MIMETYPE )

		@filter.handle_response( @response, @request )
	end
	
	
	it "does no conversion if the client doesn't accept HTML" do
		@request.should_receive( :explicitly_accepts? ).
			with( XHTML_MIMETYPE ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )
		
		@filter.handle_response( @response, @request )
	end	
end

# vim: set nosta noet ts=4 sw=4:
