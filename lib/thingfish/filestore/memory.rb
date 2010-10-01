#!/usr/bin/env ruby
#
# An in-memory filestore plugin for ThingFish.
#
# == Synopsis
#
#   require 'thingfish/filestore'
#
#   fs =ThingFish::Filestore.create( "memory" )
#
#   fs.write( uuid, data )
#   fs.read( uuid )
#   fs.delete( uuid )
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

require 'digest/md5'

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/filestore'

### An in-memory filestore plugin for ThingFish
class ThingFish::MemoryFileStore < ThingFish::FileStore

	# The default maximum size of the store
	DEFAULT_MAXSIZE = 2 ** 18  # 256k

	### Create a new MemoryFileStore
	def initialize( ignored_datadir=nil, ignored_spooldir=nil, options={} )
		super
		@data = {}
		@options[:maxsize] ||= DEFAULT_MAXSIZE
	end


	######
	public
	######

	### Mandatory FileStore interface

	### FileStore API: write the specified +data+ to the store at the given +uuid+
	### and return a hash of the data.
	def store( uuid, data )
		raise ThingFish::FileStoreQuotaError, "Out of memory quota" if
			self.total_size + data.length > @options[:maxsize]

		@data[ uuid.to_s ] = data
		return Digest::MD5.hexdigest( data )
	end


	### FileStore API: read the data in the store at the given +uuid+.
	def fetch( uuid )
		return @data[ uuid.to_s ]
	end


	### FileStore API: delete the data in the store at the given +uuid+ and return its
	### data (if it existed).
	def delete( uuid )
		return @data.delete( uuid.to_s ) ? true : false
	end


	### Return +true+ if the store has a file corresponding to the specified +uuid+.
	def has_file?( uuid )
		return @data.key?( uuid.to_s )
	end


	### Return the size of the resource corresponding to the given +uuid+ in bytes.
	### Returns +nil+ if the given +uuid+ is not in the store.
	def size( uuid )
		return nil unless @data.key?( uuid.to_s )
		return @data[ uuid.to_s ].length
	end


	### Mandatory Admin interface

	### Return the number of bytes stored in the filestore
	def total_size
		return @data.values.inject(0) {|sum,val| sum + val.length }
	end



end # class ThingFish::MemoryFileStore

# vim: set nosta noet ts=4 sw=4:

