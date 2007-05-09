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
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish'

module ThingFish

	class Error < RuntimeError; end

	class ConfigError < ThingFish::Error; end

	class FileStoreError < ThingFish::Error; end
	class FileStoreQuotaError < ThingFish::FileStoreError; end

end

