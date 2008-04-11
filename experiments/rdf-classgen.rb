#!/usr/bin/ruby
# 
# Spike to test out class and mixin generation from RDF specs/schemas
#
#

BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).dirname.parent
	libdir = basedir + 'lib'

	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )

	require basedir + 'utils.rb'
	include UtilityFunctions
}

require 'rdf/redland'

$store = Redland::HashStore.new
$model = Redland::Model.new( $store )
$parser = Redland::Parser.new

RDF = Redland::Namespace.new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' )
RDFS = Redland::Namespace.new( 'http://www.w3.org/2000/01/rdf-schema#' )

def add_namespace( url )
	$stderr.puts "Adding %p to the model" % [url]
	$parser.parse_into_model( $model, url )
	mod = Module.new do
		@namespace = Redland::Namespace.new( url )
		
		def self::[]( term )
			@namespace[ term ]
		end
	end

end

MusicBrainz = add_namespace( 'http://www.ldodds.com/projects/musicbrainz/schema/index.rdf#' )

start_irb_session( binding() )


