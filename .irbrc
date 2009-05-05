#!/usr/bin/ruby -*- ruby -*-

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname
	libdir = basedir + "lib"

	puts ">>> Adding #{libdir} to load path..."
	$LOAD_PATH.unshift( libdir.to_s )

	Dir.glob( "plugins/*/lib" ).each do |pluginlib|
		puts ">>> Adding #{pluginlib} to load path..."
		$LOAD_PATH.unshift( pluginlib.to_s )
	end

	require basedir + 'utils'
	include UtilityFunctions
}


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

