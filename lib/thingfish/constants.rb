#!/usr/bin/ruby
#
# A collection of constants for convenience and readability
#
# == Synopsis
#
#   require 'thingfish/constants'
#
#   response = HTTP::BAD_REQUEST
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

#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'tmpdir'
require 'thingfish'


module ThingFish::Constants

	# The default listening ip or hostname
	DEFAULT_BIND_IP = '0.0.0.0'

	# The default host to connect to as a client
	DEFAULT_HOST = 'localhost'

	# The default port to listen on
	DEFAULT_PORT = 3474

	# The buffer chunker size
	DEFAULT_BUFSIZE = 2 ** 14

	# The default location of upload temporary files
	DEFAULT_SPOOLDIR = Dir.tmpdir
	

	# HTTP status and result constants
	module HTTP
		SWITCHING_PROTOCOLS 		  = 101
		PROCESSING          		  = 102

		OK                			  = 200
		CREATED           			  = 201
		ACCEPTED          			  = 202
		NON_AUTHORITATIVE 			  = 203
		NO_CONTENT        			  = 204
		RESET_CONTENT     			  = 205
		PARTIAL_CONTENT   			  = 206
		MULTI_STATUS      			  = 207

		MULTIPLE_CHOICES   			  = 300
		MOVED_PERMANENTLY  			  = 301
		MOVED              			  = 301
		MOVED_TEMPORARILY  			  = 302
		REDIRECT           			  = 302
		SEE_OTHER          			  = 303
		NOT_MODIFIED       			  = 304
		USE_PROXY          			  = 305
		TEMPORARY_REDIRECT 			  = 307

		BAD_REQUEST                   = 400
		AUTH_REQUIRED                 = 401
		UNAUTHORIZED                  = 401
		PAYMENT_REQUIRED              = 402
		FORBIDDEN                     = 403
		NOT_FOUND                     = 404
		METHOD_NOT_ALLOWED            = 405
		NOT_ACCEPTABLE                = 406
		PROXY_AUTHENTICATION_REQUIRED = 407
		REQUEST_TIME_OUT              = 408
		CONFLICT                      = 409
		GONE                          = 410
		LENGTH_REQUIRED               = 411
		PRECONDITION_FAILED           = 412
		REQUEST_ENTITY_TOO_LARGE      = 413
		REQUEST_URI_TOO_LARGE         = 414
		UNSUPPORTED_MEDIA_TYPE        = 415
		RANGE_NOT_SATISFIABLE         = 416
		EXPECTATION_FAILED            = 417
		UNPROCESSABLE_ENTITY          = 422
		LOCKED                        = 423
		FAILED_DEPENDENCY             = 424

		SERVER_ERROR          		  = 500
		NOT_IMPLEMENTED       		  = 501
		BAD_GATEWAY           		  = 502
		SERVICE_UNAVAILABLE   		  = 503
		GATEWAY_TIME_OUT      		  = 504
		VERSION_NOT_SUPPORTED 		  = 505
		VARIANT_ALSO_VARIES   		  = 506
		INSUFFICIENT_STORAGE  		  = 507
		NOT_EXTENDED          		  = 510
	end


	module Patterns
		# Patterns for matching UUIDs and parts of UUIDs
		HEX12 = /[[:xdigit:]]{12}/
		HEX8  = /[[:xdigit:]]{8}/
		HEX4  = /[[:xdigit:]]{4}/
		HEX2  = /[[:xdigit:]]{2}/

		UUID_REGEXP = /#{HEX8}-#{HEX4}-#{HEX4}-#{HEX4}-#{HEX12}/

		# Network IO patterns
		CRLF = /\r?\n/
		BLANK_LINE = /#{CRLF}#{CRLF}/
	end


end # module ThingFish::Constants
