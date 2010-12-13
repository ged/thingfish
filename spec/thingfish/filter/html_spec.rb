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
require 'thingfish/behavior/filter'
require 'thingfish/filter/html'



#####################################################################
###	C O N T E X T S
#####################################################################
describe ThingFish::HtmlFilter do

	before( :all ) do
		setup_logging( :fatal )
	end

	let( :filter ) do
		ThingFish::Filter.create( 'html', {} )
	end

	before( :each ) do
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
		reset_logging()
	end


	it_should_behave_like "a filter"


	it "uses handler HTML API to convert Ruby-object responses to HTML if the client accepts it" do
		@request.should_receive( :explicitly_accepts? ).
			with( ThingFish.configured_html_mimetype ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		body = mock( "response body" )
		@response.should_receive( :body ).and_return( body )

		@last_handler.should_receive( :respond_to? ).with( :make_html_content ).
			and_return( true )
		@first_handler.should_not_receive( :make_html_content )
		@middle_handler.should_not_receive( :make_html_content )
		@last_handler.should_receive( :make_html_content ).
			with( body, @request, @response ).
			and_return( 'last_html' )

		erbtemplate = mock( "ERB wrapper template" ).as_null_object
		self.filter.stub!( :get_erb_resource ).and_return( erbtemplate )
		erbtemplate.should_receive( :result ).
			with( an_instance_of(Binding) ).
			and_return( :wrapped_html_content )

		@response.should_receive( :body= ).with( :wrapped_html_content )
		# Transform filters shouldn't change the status of the response
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( ThingFish.configured_html_mimetype )

		self.filter.handle_response( @response, @request )
	end


	it "uses the HtmlInspectableObject interface to convert responses to HTML if none of " +
	   "the handlers implements the HTML filter API" do
		@request.should_receive( :explicitly_accepts? ).
			with( ThingFish.configured_html_mimetype ).
			and_return( true )
		@response.should_receive( :content_type ).
			at_least( :once ).
			and_return( RUBY_MIMETYPE )

		body = mock( "response body" )
		@response.should_receive( :body ).at_least( :once ).and_return( body )

		@last_handler.should_receive( :respond_to? ).
			with( :make_html_content ).
			and_return( false )
		@first_handler.should_not_receive( :make_html_content )
		@middle_handler.should_not_receive( :make_html_content )
		@last_handler.should_not_receive( :make_html_content )

		body.should_receive( :html_inspect ).and_return( "some html" )

		erbtemplate = mock( "ERB wrapper template" ).as_null_object
		self.filter.stub!( :get_erb_resource ).and_return( erbtemplate )
		erbtemplate.should_receive( :result ).
			with( an_instance_of(Binding) ).
			and_return( :wrapped_html_content )

		@response.should_receive( :body= ).with( :wrapped_html_content )
		# Transform filters shouldn't change the status of the response
		@response.should_not_receive( :status= ).with( HTTP::OK )
		@response.should_receive( :content_type= ).with( ThingFish.configured_html_mimetype )

		self.filter.handle_response( @response, @request )
	end


	it "does no conversion if the client doesn't accept HTML" do
		@request.should_receive( :explicitly_accepts? ).
			with( ThingFish.configured_html_mimetype ).
			and_return( false )

		@response.should_not_receive( :body= )
		@response.should_not_receive( :status= )
		@response_headers.should_not_receive( :[]= )

		self.filter.handle_response( @response, @request )
	end
end

# vim: set nosta noet ts=4 sw=4:
