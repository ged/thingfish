#!/usr/bin/ruby -*- ruby -*-

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.expand_path
	libdir = basedir + "lib"

	puts ">>> Adding #{libdir} to load path..."
	$LOAD_PATH.unshift( libdir.to_s )

	Pathname.glob( "plugins/*/lib" ).each do |pluginlib|
		puts ">>> Adding #{pluginlib} to load path..."
		$LOAD_PATH.unshift( pluginlib.to_s )
	end

	require basedir + 'utils'
	include UtilityFunctions
}


# Modify prompt to do highlighting unless we're running in an inferior shell.
unless ENV['EMACS']
	IRB.conf[:PROMPT][:thingfish] = { # name of prompt mode
		:PROMPT_I => colorize( "%N(%m):%03n:%i>", %w{bold white on_blue} ) + " ",
		:PROMPT_S => colorize( "%N(%m):%03n:%i%l", %w{white on_blue} ) + " ",
		:PROMPT_C => colorize( "%N(%m):%03n:%i*", %w{white on_blue} ) + " ",
		:RETURN => "    ==> %s\n\n"      # format to return value
	}
	#IRB.conf[:PROMPT_MODE] = :thingfish
end

# Try to require the 'thingfish' library
begin
	require 'thingfish'
	require 'thingfish/daemon'
	require 'thingfish/config'
	
	if $DEBUG
		puts "Setting up the logging callback..."
		PluginFactory::logger_callback = lambda do |lvl, msg|
			debug_msg "[%s] %s" % [ lvl.to_s, msg ]
		end
	end	
rescue => e
	$stderr.puts "Ack! Thingfish library failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end

$deferr.puts "Turning on history..."
IRB.conf[:SAVE_HISTORY] = 100_000
IRB.conf[:HISTORY_FILE] = "~/.irb.hist"


