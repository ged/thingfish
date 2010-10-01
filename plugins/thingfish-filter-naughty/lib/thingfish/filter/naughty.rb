#!/usr/bin/env ruby

require 'thingfish'
require 'thingfish/mixins'
require 'thingfish/constants'
require 'thingfish/acceptparam'
require 'thingfish/filter'

#
# A naughty filter for ThingFish
#
# == Version
#
#  $Id$
#
# == Authors
#
# * Michael Granger <ged@FaerieMUD.org>
# * Mahlon E. Smith <mahlon@martini.nu>
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.
#
class ThingFish::NaughtyFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# VCS Revision
	VCSRev = %q$Rev$

	# The Array of types this filter is interested in
	HANDLED_TYPES = [ ThingFish::AcceptParam.parse('*/*') ]
	HANDLED_TYPES.freeze


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Spit out warnings on startup and require an additional, very
	### verbose configuration key.
	def initialize( options={} )
		raise "You probably don't want this filter installed.  Really." unless
			options['enable'] == 'yes, I understand this is just for testing'

		self.log.warn '*' * 70
		self.log.warn 'You have enabled the naughty filter! Abandon all hope ye who enter here.'
		self.log.warn '*' * 70

		super
	end

	######
	public
	######

	### Filter incoming requests
	def handle_request( request, response )
		request.each_body do |body,metadata|
			self.log.warn "Being naughty with request body %p" % [ body ]
			body.read
			body.close
		end
	end


	### Filter reponses -- no-op until we have a clearer plan for response "bodies"
	def handle_response( response, request )
		# if response.is_a?( IO )
		# 	response.body.read
		# 	response.body.close
		# end
	end


	### Return an Array of ThingFish::AcceptParam objects which describe which content types
	### the filter is interested in. The default returns */*, which indicates that it is
	### interested in all requests/responses.
	def handled_types
		return HANDLED_TYPES
	end


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [1, 0],       # Filter version
	###     'supports'  => [],           # Any specific version information unique to the filter
	###     'rev'       => 460,          # VCS rev of plugin
	###     'accepts'   => [...],        # Mimetypes the filter accepts from requests
	###     'generates' => [...],        # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }

		return {
			'version'   => [1,0],
			'supports'  => [],
			'rev'       => VCSRev.match( /: (\w+)/ )[1] || 0,
			'accepts'   => accepts,
			'generates' => [],
		  }
	end

end # class ThingFish::NaughtyFilter

# vim: set nosta noet ts=4 sw=4:


