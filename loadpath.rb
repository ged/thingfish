#!/usr/bin/env ruby
#
# Set up the local load path (for spec mostly)

require 'pathname'

basedir = Pathname.new( __FILE__ ).expand_path.dirname
libdir = basedir + "lib"
plugin_dirs = Pathname.glob( basedir + "plugins/**/spec" )

$LOAD_PATH.unshift( libdir, *plugin_dirs )

