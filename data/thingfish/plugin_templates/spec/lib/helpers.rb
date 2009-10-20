#!/usr/bin/ruby
# coding: utf-8

begin
	require 'thingfish'
	require 'thingfish/constants'
	require 'thingfish/utils'
	
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

module ThingFish::SpecHelpers

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
			ThingFish.logger.formatter = ThingFish::HtmlLogFormatter.new( logger )
		end
	end
	
end

# Override the badly-formatted output of the RSpec HTML formatter
require 'spec/runner/formatter/html_formatter'

class Spec::Runner::Formatter::HtmlFormatter
	def example_failed( example, counter, failure )
		failure_style = failure.pending_fixed? ? 'pending_fixed' : 'failed'
		
		unless @header_red
			@output.puts "    <script type=\"text/javascript\">makeRed('rspec-header');</script>"
			@header_red = true
		end
		
		unless @example_group_red
			css_class = 'example_group_%d' % [current_example_group_number || 0]
			@output.puts "    <script type=\"text/javascript\">makeRed('#{css_class}');</script>"
			@example_group_red = true
		end
		
		move_progress()
		
		@output.puts "    <dd class=\"spec #{failure_style}\">",
		             "      <span class=\"failed_spec_name\">#{h(example.description)}</span>",
		             "      <div class=\"failure\" id=\"failure_#{counter}\">"
		if failure.exception
			backtrace = format_backtrace( failure.exception.backtrace )
			message = failure.exception.message
			
			@output.puts "        <div class=\"message\"><code>#{h message}</code></div>",
			             "        <div class=\"backtrace\"><pre>#{backtrace}</pre></div>"
		end

		if extra = extra_failure_content( failure )
			@output.puts( extra )
		end
		
		@output.puts "      </div>",
		             "    </dd>"
		@output.flush
	end


	alias_method :default_global_styles, :global_styles
	
	def global_styles
		css = default_global_styles()
		css << %Q{
			/* Stuff added by #{__FILE__} */

			/* Overrides */
			#rspec-header {
				-webkit-box-shadow: #333 0 2px 5px;
				margin-bottom: 1em;
			}

			.example_group dt {
				-webkit-box-shadow: #333 0 2px 3px;
			}

			/* Style for log output */
			dd.log-message {
				background: #eee;
				padding: 0 2em;
				margin: 0.2em 1em;
				border-bottom: 1px dotted #999;
				border-top: 1px dotted #999;
				text-indent: -1em;
			}

			/* Parts of the message */
			dd.log-message .log-time {
				font-weight: bold;
			}
			dd.log-message .log-time:after {
				content: ": ";
			}
			dd.log-message .log-level {
				font-variant: small-caps;
				border: 1px solid #ccc;
				padding: 1px 2px;
			}
			dd.log-message .log-name {
				font-size: 1.2em;
				color: #1e51b2;
			}
			dd.log-message .log-name:before { content: "«"; }
			dd.log-message .log-name:after { content:  "»"; }

			dd.log-message .log-message-text {
				padding-left: 4px;
				font-family: Monaco, "Andale Mono", "Vera Sans Mono", mono;
			}


			/* Distinguish levels */
			dd.log-message.debug { color: #666; }
			dd.log-message.info {}

			dd.log-message.warn,
			dd.log-message.error {
				background: #ff9;
			}
			dd.log-message.error .log-level,
			dd.log-message.error .log-message-text {
				color: #900;
			}
			dd.log-message.fatal {
				background: #900;
				color: white;
				font-weight: bold;
				border: 0;
			}
			dd.log-message.fatal .log-name {
				color:  white;
			}
		}
		
		return css
	end
end

