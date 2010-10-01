#!/usr/bin/env ruby
#
# Load the Dublin Core and the RDF namespace and schema into a model and drop into IRB
# 
# Time-stamp: <24-Aug-2003 16:11:13 deveiant>
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname.parent
	libdir = basedir + "lib"

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )

	require basedir + "utils.rb"
	include UtilityFunctions
}


require 'rdf/redland'
RDF = Redland

begin
	$store = RDF::TripleStore.new( 'postgresql', 'thingfish_metastore', 'database=test,host=localhost' )
	$model = RDF::Model.new( $store )
	$parser = RDF::Parser.new
rescue => err
	
	URLS = %w[
		http://purl.org/dc/elements/1.1/
		http://purl.org/dc/terms/
		http://purl.org/dc/dcmitype/
		http://www.w3.org/1999/02/22-rdf-syntax-ns
		http://www.w3.org/2000/01/rdf-schema
	]

	URLS.each do |uri|
		$stderr.print "Loading vocabulary from %p..." % [uri]
		$parser.parse_into_model( $model, uri )
		$stderr.puts " done."
	end

start_irb_session( binding() )

