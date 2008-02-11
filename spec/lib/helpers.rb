#!/usr/bin/ruby

begin
	require 'thingfish'
	require 'thingfish/constants'
	
	require 'digest/md5'
	require 'net/http'
	require 'net/protocol'

	require 'spec/lib/constants'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end

include ThingFish::TestConstants
include ThingFish::Constants

module ThingFish::TestHelpers

	### Return a Net::HTTPSuccess object with the contents set to the specified 
	### +data+.
	def with_fixtured_http_get_response( data='', code=HTTP::OK )
		data ||= ''
		raw_response = TEST_OK_HTTP_RESPONSE + "\n" + data
		io = Net::BufferedIO.new( StringIO.new(raw_response) )
		response = response_class_for_httpcode( code.to_s ).read_new( io )
		response['Content-Length'] = data.length
		response['Etag'] = %{"%s"} % Digest::MD5.hexdigest(data) if data

		response.reading_body( io, true ) do
			yield response if block_given?
		end
		return response
	end
	
	
	### Return the correct Net::HTTPResponse class for the given +code+ (because it's
	### private in Net::HTTPResponse itself)
	def response_class_for_httpcode( code )
		Net::HTTPResponse::CODE_TO_OBJ[code] or
		Net::HTTPResponse::CODE_CLASS_TO_OBJ[code[0,1]] or
		HTTPUnknownResponse
	end
	
	
	### Return a Net::HTTPSuccess object with empty contents, as if from a HEAD 
	### request.
	def with_fixtured_http_head_response
		raw_response = TEST_OK_HTTP_RESPONSE + "\n"
		io = Net::BufferedIO.new( StringIO.new(raw_response) )
		response = Net::HTTPResponse.read_new( io )

		response.reading_body( io, true ) do
			yield response if block_given?
		end
		return response
	end
	
	### Create a temporary working directory and return
	### a Pathname object for it.
	###
	def make_tempdir
		dirname = "%s.%d.%0.4f" % [
			'thingfish_spec',
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		return Pathname.new( Dir.tmpdir ) + dirname
	end	
end

require 'spec/runner/formatter/html_formatter'
class Spec::Runner::Formatter::HtmlFormatter

	def example_failed(example, counter, failure)
		extra = extra_failure_content(failure)
		failure_style = failure.pending_fixed? ? 'pending_fixed' : 'failed'

		@output.puts "    <script type=\"text/javascript\">makeRed('rspec-header');</script>" unless @header_red
		@header_red = true
		@output.puts "    <script type=\"text/javascript\">makeRed('example_group_#{current_example_group_number}');</script>" unless @example_group_red
		@example_group_red = true
		move_progress
		@output.puts "    <dd class=\"spec #{failure_style}\">"
		@output.puts "      <span class=\"failed_spec_name\">#{h(example.description)}</span>"
		@output.puts "      <div class=\"failure\" id=\"failure_#{counter}\">"
		@output.puts "        <div class=\"message\"><code>#{h(failure.exception.message)}</code></div>" unless failure.exception.nil?
		@output.puts "        <div class=\"backtrace\"><pre>#{format_backtrace(failure.exception.backtrace)}</pre></div>" unless failure.exception.nil?
		@output.puts extra unless extra == ""
		@output.puts "      </div>"
		@output.puts "    </dd>"
		@output.flush
	end

end

