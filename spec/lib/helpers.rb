#!/usr/bin/env ruby
# coding: utf-8

require 'rspec'


require 'digest/md5'
require 'net/http'
require 'net/protocol'

require 'thingfish'
require 'thingfish/testconstants'
require 'thingfish/constants'
require 'thingfish/utils'


module ThingFish::SpecHelpers
	include ThingFish::TestConstants

	class ArrayLogger
		### Create a new ArrayLogger that will append content to +array+.
		def initialize( array )
			@array = array
		end

		### Write the specified +message+ to the array.
		def write( message )
			@array << message
		end

		### No-op -- this is here just so Logger doesn't complain
		def close; end

	end # class ArrayLogger


	unless defined?( LEVEL )
		LEVEL = {
			:debug => Logger::DEBUG,
			:info  => Logger::INFO,
			:warn  => Logger::WARN,
			:error => Logger::ERROR,
			:fatal => Logger::FATAL,
		  }
	end

	###############
	module_function
	###############

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
		tempdir = Pathname.new( Dir.tmpdir ) + dirname
		tempdir.mkpath

		return tempdir
	end


	### Reset the logging subsystem to its default state.
	def reset_logging
		ThingFish.reset_logger
	end


	### Alter the output of the default log formatter to be pretty in SpecMate output
	def setup_logging( level=Logger::FATAL )

		# Turn symbol-style level config into Logger's expected Fixnum level
		if ThingFish::Loggable::LEVEL.key?( level )
			level = ThingFish::Loggable::LEVEL[ level ]
		end

		logger = Logger.new( $stderr )
		ThingFish.logger = logger
		ThingFish.logger.level = level

		# Only do this when executing from a spec in TextMate
		if ENV['HTML_LOGGING'] || (ENV['TM_FILENAME'] && ENV['TM_FILENAME'] =~ /_spec\.rb/)
			Thread.current['logger-output'] = []
			logdevice = ArrayLogger.new( Thread.current['logger-output'] )
			ThingFish.logger = Logger.new( logdevice )
			# ThingFish.logger.level = level
			ThingFish.logger.formatter = ThingFish::HtmlLogFormatter.new( logger )
		end
	end


end


RSpec.configure do |config|
	include ThingFish::TestConstants

	config.mock_with( :rspec )

	config.include( ThingFish::TestConstants )
	config.include( ThingFish::SpecHelpers )
end

