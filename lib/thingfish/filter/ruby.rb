#!/usr/bin/ruby
# 
# A Marshalled Ruby object filter for ThingFish
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          ruby: ~
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


require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### A Ruby marshalled-object filter for ThingFish. It marshals and unmarshals Ruby objects in the 
### body of responses if the client sends a request with an `Accept:` header that includes 
### ThingFish::RUBY_MARSHALLED_MIMETYPE.
class ThingFish::RubyFilter < ThingFish::Filter
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
		super
	end
	

	######
	public
	######

	### Filter incoming requests
	def handle_request( request, response )

		# Only filter if the body of the request is a marshalled Ruby object
		return unless request.content_type == RUBY_MARSHALLED_MIMETYPE
		
		# Absorb errors so filters can continue
		begin
			self.log.debug "Unmarshalling a ruby object in the entity body"
			obj = Marshal.load( request.body )
			request.body = obj
			self.log.debug "Successfully unmarshalled entity body: %p" % [ obj ]
		rescue ArgumentError => err
			self.log.error "%s while attempting to unmarshal %p: %s" %
				[ err.class.name, request.body, err.message ]
		else
			request.content_type = RUBY_MIMETYPE
		end

	end


	### Convert outgoing ruby object responses into YAML.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.explicitly_accepts?( RUBY_MARSHALLED_MIMETYPE ) &&
			self.accept?( response.content_type )

		# Errors marshalling should result in a 500.
		self.log.debug "Converting a %s response to %s" %
			[ response.content_type, RUBY_MARSHALLED_MIMETYPE ]
		response.body = Marshal.dump( response.body )
		response.content_type = RUBY_MARSHALLED_MIMETYPE
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end
	
	
end # class ThingFish::YAMLFilter

# vim: set nosta noet ts=4 sw=4:

