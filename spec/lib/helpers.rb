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


require 'spec/mocks/message_expectation'

### Monkeypatch: RSpec doesn't allow for a mock that should both yield and return a value
### different than the last value of the block that was yielded to.
class Spec::Mocks::BaseExpectation

	# Reset the return block and return self to allow chaining an #and_return after
	# an #and_yield
	def and_yield( *args )
		@args_to_yield = args
		@return_block = nil
		return self
	end

	def invoke_with_yield(block)
		if block.nil?
			@error_generator.raise_missing_block_error @args_to_yield
		end
		if block.arity > -1 && @args_to_yield.length != block.arity
			@error_generator.raise_wrong_arity_error @args_to_yield, block.arity
		end
		rval = block.call(*@args_to_yield)

		if @return_block
			return @return_block.call
		else
			return rval
		end
	end

end



