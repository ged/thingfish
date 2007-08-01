#!/usr/bin/ruby
# 
# The base filter type for ThingFish
# 
# == Synopsis
# 
#   require 'thingfish/filter'
#
#   class MyFilter < ThingFish::Filter
#     
#   end
#
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

require 'pathname'
require 'pluginfactory'
require 'thingfish'
require 'thingfish/mixins'


### Base class for ThingFish Filter plugins
class ThingFish::Filter
	include PluginFactory, ThingFish::Loggable


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
		['thingfish/filter']
	end

	
	### PluginFactory interface: Return a sprintf string which describes the naming
	### convention of plugin gems for this class. The results will be used as an
	### argument to the 'Kernel::gem' function.
	def self::rubygem_name_pattern
		'thingfish-%sfilter'
	end


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Set up a new Handler object
	def initialize( options={} )
		@config = nil
		super
	end
	

	######
	public
	######

	

end # class ThingFish::Filter

# vim: set nosta noet ts=4 sw=4:

