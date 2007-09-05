#!/usr/bin/ruby
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

module ThingFish

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

	# Something was wrong with a request
	class RequestError < ThingFish::Error
		
   	end

	# Something was wrong with a response
	class ResponseError < ThingFish::Error; end
	
end

