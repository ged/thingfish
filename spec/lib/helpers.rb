#!/usr/bin/ruby

begin
	require 'thingfish'
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


module ThingFish::TestHelpers
	include ThingFish::TestConstants

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
			Pathname.new( __FILE__ ).basename('.rb'),
			Process.pid,
			(Time.now.to_f % 3600),
		  ]
		return Pathname.new( Dir.tmpdir ) + dirname
	end	
end

