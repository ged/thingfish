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
#          # fetch the data for +uuid+ and return it
#      end
#
#      def store( uuid, data )
#          # store the +data+ to the resource specified
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
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the top-level directory for licensing details.

#

require 'stringio'
require 'pluginfactory'
require 'thingfish'
require 'thingfish/mixins'


### Base class for ThingFish FileStore plugins
class ThingFish::FileStore
	include PluginFactory,
	        ThingFish::Loggable,
	        ThingFish::AbstractClass,
			ThingFish::HtmlInspectableObject

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


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new ThingFish::FileStore object.
	def initialize( datadir, spooldir, options={} )
		@datadir  = datadir
		@spooldir = spooldir
		@options  = options

		super()
	end


	######
	public
	######

	# The directory this filestore will store stuff in (if it uses files)
	attr_reader :datadir

	# The directory this filestore will use for temporary files
	attr_reader :spooldir


	### Perform any startup tasks that should take place after the daemon has an opportunity
	### to daemonize and switch effective user.  This can be overridden from child classes.
	def on_startup
		# default no-op
	end


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
		io = StringIO.new( self.fetch(uuid) )
		yield( io ) if block_given?
		return io
	end

end # class ThingFish::FileStore

# vim: set nosta noet ts=4 sw=4:

