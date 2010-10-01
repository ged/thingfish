#!/usr/bin/env ruby
#
# A collection of exceptions for exceptional error handling.  har!
#
# == Synopsis
#
#   None.
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

require 'thingfish'

module ThingFish
	require 'thingfish/constants'

	# General ThingFish exception class
	class Error < RuntimeError; end

	# Error in configuration file
	class ConfigError < ThingFish::Error; end

	# Error in a plugin
	class PluginError < ThingFish::Error; end

	# Error in a filestore plugin
	class FileStoreError < ThingFish::PluginError; end

	# Some action could not be completed because it would make the filestore exceed
	# its allotted quota.
	class FileStoreQuotaError < ThingFish::FileStoreError; end

	# Error in a metastore plugin
	class MetaStoreError < ThingFish::PluginError; end

	# Something was wrong with a response
	class ResponseError < ThingFish::Error; end

	# Error in a resource
	class ResourceError < ThingFish::Error; end

	# Error in an instance of the client
	class ClientError < ThingFish::Error; end

	# 500: The server was unable to handle the request even though it was valid
	class ServerError < ThingFish::Error
		include ThingFish::Constants

		def initialize( *args )
			super
			@status = HTTP::SERVER_ERROR
		end

		attr_reader :status
	end

	# 500: Error while dispatching a request
	class DispatchError < ThingFish::ServerError; end

	# 501: We received a request that we don't quite know how to handle.
	class NotImplementedError < ThingFish::ServerError
		include ThingFish::Constants

		def initialize( *args )
			super
			@status = HTTP::NOT_IMPLEMENTED
		end

		attr_reader :status
	end

	# 400: Something was wrong with a request
	class RequestError < ThingFish::Error
		include ThingFish::Constants

		def initialize( *args )
			super
			@status = HTTP::BAD_REQUEST
		end

		attr_reader :status
	end

	# 413: Upload exceeded quota
	class RequestEntityTooLargeError < ThingFish::RequestError
		include ThingFish::Constants

		def initialize( *args )
			super
			@status = HTTP::REQUEST_ENTITY_TOO_LARGE
		end
	end

	# 406: Client requested a mimetype we don't know how to convert to
	class RequestNotAcceptableError < ThingFish::RequestError
		include ThingFish::Constants

		def initialize( *args )
			super
			@status = HTTP::NOT_ACCEPTABLE
		end
	end

	# Generic timeout exception
	class Timeout < Exception; end
end

