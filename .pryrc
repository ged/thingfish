#!/usr/bin/ruby -*- ruby -*-

require 'loggability'
require 'pathname'

$LOAD_PATH.unshift( 'lib' )
$LOAD_PATH.unshift( '../Strelka/lib' )
$LOAD_PATH.unshift( '../Mongrel2/lib' )

begin
	require 'thingfish'
	require 'thingfish/handler'

	Loggability.level = :debug
	Loggability.format_with( :color )

rescue Exception => e
	$stderr.puts "Ack! Thingfish libraries failed to load: #{e.message}\n\t" +
		e.backtrace.join( "\n\t" )
end


