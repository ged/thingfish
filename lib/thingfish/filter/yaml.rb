#!/usr/bin/ruby
# 
# A YAML conversion filter for ThingFish
# 
# == Synopsis
# 
#   plugins:
#       filters:
#          yaml: ~
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

require 'yaml'

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'


### A YAML-conversion filter for ThingFish. It converts Ruby objects in the body of responses 
### to YAML if the client accepts 'text/x-yaml'.
class ThingFish::YAMLFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	# The Array of types this filter is interested in
	HANDLED_TYPES = [ ThingFish::AcceptParam.parse(RUBY_MIMETYPE) ]
	HANDLED_TYPES.freeze
	
	# The YAML mime type.
	YAML_MIMETYPE = 'text/x-yaml'
	YAML_MIMETYPE.freeze


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Filter object
	def initialize( options={} ) # :notnew:
		super
	end
	

	######
	public
	######w

	### Filter incoming requests, converting YAML to native ruby objects.
	def handle_request( request, response )

		# Only filter if the client sends what we can convert from.
		return unless request.content_type &&
			request.content_type.downcase == YAML_MIMETYPE
		
		# Absorb errors so filters can continue
		begin
			self.log.debug "Converting a %s request to %s" %
				[ YAML_MIMETYPE, RUBY_MIMETYPE ]
			request.body = YAML.load( request.body.read )
		rescue RuntimeError, YAML::ParseError => err
			self.log.error "%s while attempting to convert %p to a native ruby object: %s" %
				[ err.class.name, request.body, err.message ]
			self.log.debug err.backtrace.join("\n")	
		else
			request.content_type = RUBY_MIMETYPE
		end
	end


	### Convert outgoing ruby object responses into YAML.
	def handle_response( response, request )

		# Only filter if the client wants what we can convert to, and the response body
		# is something we know how to convert
		return unless request.explicitly_accepts?( YAML_MIMETYPE ) &&
			self.accept?( response.content_type )
		
		# Errors converting to yaml should result in a 500.
		self.log.debug "Converting a %s response to text/x-yaml" %
			[ response.content_type ]				
		response.body = self.stringify_members( response.body ).to_yaml
		response.content_type = YAML_MIMETYPE
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is 
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end
	
	
	#########
	protected
	#########
	
	### Walk over the contents of +data+, stringifying contents.
	def stringify_members( data )
		case data
		when Hash
			data.each_key {|k| data[ k.to_s ] = stringify_members(data.delete(k)) }
			
		when Array
			data.collect {|obj| stringify_members(obj) }
			
		else
			data.to_s
		end
	end
	
end # class ThingFish::YAMLFilter

# vim: set nosta noet ts=4 sw=4:

