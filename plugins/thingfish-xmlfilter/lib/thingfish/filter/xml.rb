#!/usr/bin/ruby
# 
# An XML conversion filter for ThingFish.
# 
# Requires ClXMLSerial and Tidy.
#      http://clabs.org/clxmlserial.htm 
#      http://rubyforge.org/projects/tidy/
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          xml:
#              tidypath: /path/to/tidy/library.so
# 
# == Config Keys
# 
# 	[+tidypath+]
# 		Path to the installed Tidy shared library.  If not specified,
# 		uses the OSX default path.
#
#
# == Version
#
#  $Id$
# 
# == Authors
# 
# * Michael Granger <mgranger@laika.com>
# * Mahlon E. Smith <mahlon@laika.com>
# 
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

begin
	require 'cl/xmlserial'
	require 'tidy'

	require 'thingfish'
	require 'thingfish/mixins'
	require 'thingfish/constants'
	require 'thingfish/acceptparam'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### Allow some additional base classes to be XML serialized.
class NilClass; include XmlSerialization; end
class Symbol
	include XmlSerialization

	def instance_data_to_xml( element )
		element.add_text( self.to_s )
	end
end


### An XML-conversion filter for ThingFish. It converts Ruby objects in
### the body of responses to XML if the client accepts 'application/xml'.
class ThingFish::XMLFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The Array of types this filter is interested in
	HANDLED_TYPES = [ ThingFish::AcceptParam.parse(RUBY_MIMETYPE) ]
	HANDLED_TYPES.freeze
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options={} ) # :notnew:

		XSConf.outputTypeElements = true

		# Determine if we should use Tidy for XML cleanup.
		@use_tidy = false
		tidylib = ( ! options.nil? && options[:tidypath] ) || '/usr/lib/libtidy.dylib'
		if ( File.exist?( tidylib ) )
			Tidy.path = tidylib
			@use_tidy = true
		end

		super()
	end
	

	######
	public
	######

	### Filter incoming requests (no-op currently)
	def handle_request( request, response )
	end


	### Convert outgoing ruby object responses into XML.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.accept?( 'application/xml' ) &&
			self.accept?( response.headers[:content_type] )
		
		# Absorb errors so filters can continue
		begin
			self.log.debug "Converting a %s response to application/xml" %
				[ response.headers[:content_type] ]
			response.body = self.make_xml( response.body )
		rescue => err
			self.log.error "%s while attempting to convert %p to XML: %s" %
				[ err.class.name, response.body, err.message ]
		else
			response.headers[:content_type] = 'application/xml'
			response.status = HTTP::OK
		end
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which
	### content types the filter is interested in. The default returns */*,
	### which indicates that it is interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end
	

	#########
	protected
	#########

	### Pass the response +body+ through the XML serializer and tidy.
	###
	def make_xml( body )
		return body.to_xml unless @use_tidy
		return Tidy.open do |tidy|
			 tidy.options.output_xml = true
			 tidy.options.input_xml  = true
			 tidy.options.indent     = true
			 xml = tidy.clean( body.to_xml )
			 xml
		end
	end
	
end # class ThingFish::XMLFilter

# vim: set nosta noet ts=4 sw=4:


