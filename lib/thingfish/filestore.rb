#!/usr/bin/ruby
#
# The abstract base filestore class for ThingFish
#
# == Synopsis
#  require 'thingfish/filestore'
#
#  ### Define a new filestore backend:
#  # lib/thingfish/netappfilestore.rb
#
#  class ThingFish::NetAppFileStore < ThingFish::FileStore
#      def initialize( config )
#          super
#          # ...
#      end
#
#      def fetch( uuid )
#          # fetch an IO for the data for +uuid+ and return it
#      end
#
#      def store( uuid, io )
#          # store the +data+ from the given +io+ to the resource specified 
#          # by the given +uuid+ and return a hex digest for the file
#      end
#
#      def delete( uuid )
#          # delete the resource specified by the given +uuid+
#      end
#  end # class ThingFish::NetAppFileStore
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

require 'stringio'
require 'pluginfactory'
require 'thingfish'
require 'thingfish/mixins'


### Base class for ThingFish FileStore plugins
class ThingFish::FileStore
	include PluginFactory,
	        ThingFish::Loggable,
	        ThingFish::AbstractClass

	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$



	#################################################################
	###	C L A S S   M E T H O D S
	#################################################################

	### PluginFactory interface: Return an Array of prefixes to use when searching 
	### for derivatives.
	def self::derivative_dirs
		['thingfish/filestore']
	end
	

	### PluginFactory interface: Return a sprintf string which describes the naming
	### convention of plugin gems for this class. The results will be used as an
	### argument to the 'Kernel::gem' function.
	def self::rubygem_name_pattern
		'thingfish-%sfs'
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new ThingFish::FileStore object.
	def initialize( options={} )
		@options = options
		super()
	end


	######
	public
	######

	### Mandatory FileStore API
	virtual :store, :fetch, :delete, :size, :has_file?

	alias_method :[]=, :store
	alias_method :[], :fetch


	### Mandatory Admin API
	virtual :total_size

	

	### Optional IO efficiency interface with fallbacks

	### Store the data read from the given +io+ in the store at the given +uuid+.
	def store_io( uuid, io )
		return self.store( uuid, io.read )
	end
	

	### Call the supplied block with an IO object opened to the data for the given
	### +uuid+.
	def fetch_io( uuid )
		yield StringIO.new( self.fetch(uuid) )
	end

end # class ThingFish::FileStore

# vim: set nosta noet ts=4 sw=4:

