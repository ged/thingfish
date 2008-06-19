#!/usr/bin/ruby
# 
# A basicauth filter for ThingFish
# 
# == Version
#
#  $Id$
# 
# == Authors
# 
# * Mahlon E. Smith <mahlon@laika.com>
# * Michael Granger <mgranger@laika.com>
# 
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

begin
	require 'thingfish'
	require 'thingfish/mixins'
	require 'thingfish/constants'
	require 'thingfish/acceptparam'
	require 'thingfish/filter'
rescue LoadError
	unless Object.const_defined?( :Gem )
		require 'rubygems'
		retry
	end
	raise
end


### A basicauth filter for ThingFish
class ThingFish::BasicAuthFilter < ThingFish::Filter
	include ThingFish::Loggable,
		ThingFish::Constants

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$


	# The header to set to indicate how to authenticate
	AUTHENTICATE_HEADER = 'WWW-Authenticate'
	
	# The header to read authorization credentials from
	AUTHORIZATION_HEADER = 'Authorization'
	
	# The default authentication realm
	DEFAULT_AUTH_REALM = 'ThingFish'
	
	

	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new ThingFish::BasicAuthFilter.
	def initialize( options={} )
		@users = options['users'] || {}
		@realm = options['realm'] || DEFAULT_AUTH_REALM

		uris  = options['uris']  || ['/']
		uris = [ uris ] unless uris.is_a?( Array )
		uri_patterns = uris.collect do |path|
			Regexp.new( '^' + Regexp.escape(path) + '\\b' )
		end
		@uripattern = Regexp.union( *uri_patterns )
		self.log.debug "Protected URI pattern is: %p" % [ @uripattern ]
		
		super
	end
	
	
	######
	public
	######

	# Base URIs authentication applies to.
	attr_reader :uris
	
	# Accounts that can login ( user => pass )
	attr_reader :users

	
	### Filter incoming requests
	def handle_request( request, response )
		self.log.debug "Checking authentication"

		if @uripattern =~ request.path
			authenticated = false
			
			if authstring = request.headers[ AUTHORIZATION_HEADER ]
				authscheme, credentials = authstring.split( /\s+/, 2 )
			
				authenticated = self.authenticate( request, authscheme, credentials )
			else
				self.log.info "No authentication provided"
			end

			unless authenticated
				response.status = HTTP::AUTH_REQUIRED
				response.headers[ AUTHENTICATE_HEADER ] = %Q{Basic realm="%s"} % [ @realm ]
			end
		else
			self.log.debug "URI path %p didn't match a protected URI; skipping authentication" %
			 	[ request.path ]
		end
		
	end
	
	
	### Filter outgoing responses (No-op)
	def handle_response( response, request )
	end
	


	### Returns a Hash of information about the filter; this is of the form:
	###   {
	###     'version'   => [1, 0],       # Filter version
	###     'supports'  => [],           # Any specific version information unique to the filter
	###     'rev'       => 460,          # SVN rev of plugin
	###     'accepts'   => [...],        # Mimetypes the filter accepts from requests
	###     'generates' => [...],        # Mimetypes the filter can convert responses to
	###   }
	def info
		accepts = self.handled_types.map {|ap| ap.mediatype }
		
		return {
			'version'   => [1,0],
			'supports'  => [],
			'rev'       => Integer( SVNRev[/\d+/] || 0 ),
			'accepts'   => accepts,
			'generates' => [],
		  }
	end
	
	
	#########
	protected
	#########

	### Check the given +credentials+ and return true if they are valid for the request's URI.
	def authenticate( request, authscheme, credentials )
		unless authscheme.downcase == 'basic'
			self.log.warn "Unsupported authentication scheme: %s" % [ authscheme ]
			return false
		end
			
		unless credentials.unpack('m').first.match( /^([^:]+):(.*)$/ )
			self.log.error "Malformed authentication credentials"
			return false
		end

		username, password = $1, $2

		unless @users[ username ] == password
			self.log.warn "Authentication failure for %s" % [ username ]
			return false
		end
		
		self.log.info "Authenticated user %p" % [ username ]
		request.authed_user = username
		return true
	end
	
end # class ThingFish::BasicAuthFilter

# vim: set nosta noet ts=4 sw=4:


