#!/usr/bin/ruby
# 
# An XML conversion filter for ThingFish.
# 
# Requires ClXMLSerial and Tidy.
#      http://clabs.org/clxmlserial.htm 
#      http://rubyforge.org/projects/tidy/
# 
# *** This was originally created for demonstration purposes.  It isn't especially
#     useful for any practical purpose.  If you really want to use XML instead of
#     YAML, JSON, or another decent serialization library, you should probably
#     subclass this and modify to taste.
#
# == Synopsis
# 
#   plugins:
#     filters:
#       xml:
#         usetidy: true
#         tidypath: /path/to/tidy/library.so
# 
# == Config Keys
# 
# 	[+usetidy+]
# 		Enable use of the Tidy library for pretty-indented XML output.
#
# 	[+tidypath+]
# 		Path to the installed Tidy shared library.  If not specified,
# 		looks for it the library in the same directory as libruby.
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
	require 'rbconfig'
	require 'cl/xmlserial'
	require 'ipaddr'
	
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
module XmlStringifiable
	def instance_data_to_xml( element )
		element.add_text( self.to_s )
	end
end

[ NilClass, Symbol, IPAddr ].each do |klass|
	XmlSerialization.send( :append_features, klass )
	XmlStringifiable.send( :append_features, klass )
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
	
	# The XML mime type.
	XML_MIMETYPE = 'application/xml'
	XML_MIMETYPE.freeze
	
	# The default path to libtidy to try in case the user doesn't configure one
	DEFAULT_TIDYLIB_PATH = "%s/libtidy.%s" % Config::CONFIG.values_at( 'libdir', 'DLEXT' )
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options=nil ) # :notnew:
		options ||= {}

		XSConf.outputTypeElements = true

		# Determine if we should use Tidy for XML cleanup.
		@use_tidy = false
		configure_tidy( options ) if options['usetidy']

		super
	end
	

	######
	public
	######

	### Filter incoming requests (currently unsupported for XML)
	def handle_request( request, response )
	end


	### Convert outgoing ruby object responses into XML.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.explicitly_accepts?( XML_MIMETYPE ) &&
			self.accept?( response.content_type )
		
		# Errors converting to XML should result in a 500.
		self.log.debug "Converting a %s response to %s" %
			[ response.content_type, XML_MIMETYPE ]
		response.body = self.make_xml( response.body )
		response.content_type = XML_MIMETYPE
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
	def make_xml( body )
		xml = body.to_xml
		
		if @use_tidy
			xml = Tidy.open do |tidy|
				tidy.options.output_xml = true
				tidy.options.input_xml  = true
				tidy.options.indent     = true
				tidy.clean( xml )
			end
		end
		
		return xml
	end


	#######
	private
	#######

	### Try to configure Tidy if it's enabled
	def configure_tidy( options )
		self.log.debug "Attempting to enable Tidy"
		require 'tidy'
		
		tidylib = options['tidypath'] || DEFAULT_TIDYLIB_PATH

		if File.exist?( tidylib )
			Tidy.path = tidylib
			@use_tidy = true
			self.log.info "XMLFilter: Tidy support enabled."
		else
			self.log.error "XMLFilter: Can't use Tidy: %s: no such file" % [ tidylib ]
		end

	rescue LoadError => err
		self.log.error "Can't use Tidy: %s" % [ err.message ]
	end
	
end # class ThingFish::XMLFilter

# vim: set nosta noet ts=4 sw=4:


