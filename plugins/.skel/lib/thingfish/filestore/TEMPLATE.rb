#!/usr/bin/ruby
#
# <%= vars[:name] %> -- a filestore plugin for ThingFish.
#
# == Synopsis
#
#   require 'thingfish/filestore'
#
#   fs = ThingFish::Filestore.create( "<%= vars[:name] %>" )
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
# * <%= vars[:author] %>
#
#:include: LICENSE
#
#---
#
# Please see the file LICENSE in the base directory for licensing details.
#

require 'thingfish'
require 'thingfish/exceptions'
require 'thingfish/filestore'


### <%= vars[:name] %> -- a filestore plugin for ThingFish
class ThingFish::<%= vars[:name].capitalize %>FileStore < ThingFish::FileStore

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	
	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new FilesystemFileStore
	def initialize( options={} )
		super

		# ... other initialization
	end



	######
	public
	######

	### Mandatory FileStore interface

	### FileStore API: write the specified +data+ to the store at the given +uuid+.
	def store( uuid, data )
		# ...
	end


	### FileStore API: Store the data read from the given +io+ in the store at the given +uuid+.
	#def store_io( uuid, io )
	#end
	

	### FileStore API: read the data in the store at the given +uuid+.
	def fetch( uuid )
		# ...
	end
	
	
	### FileStore API: Retrieve an IO for the data corresponding to the given +uuid+.
	#def fetch_io( uuid, &block )
	#end
	

	### FileStore API: delete the data in the store at the given +uuid+ and return its
	### data (if it existed).
	def delete( uuid )
		# ...
	end


	### Return +true+ if the store has a file corresponding to the specified +uuid+.
	def has_file?( uuid )
		# ...
	end


	### Return the size of the resource corresponding to the given +uuid+ in bytes. 
	### Returns +nil+ if the given +uuid+ is not in the store.
	def size( uuid )
		# ...
	end
	
	
	### Mandatory Admin interface

	### Return the number of bytes stored in the filestore
	def total_size
		# ...
	end

		
end # class ThingFish::<%= vars[:name].capitalize %>FileStore

# vim: set nosta noet ts=4 sw=4:
