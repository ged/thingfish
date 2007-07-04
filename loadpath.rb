BEGIN {
	require 'pathname'
	basedir = Pathname.new( __FILE__ ).expand_path.dirname
	
	libdir = basedir + 'lib'
	pluginsdir = basedir + 'plugins'
	pluginlibs = Pathname.glob( pluginsdir + '*/lib' )
	
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
	pluginlibs.each do |dir|
		$LOAD_PATH.unshift( dir.to_s ) unless $LOAD_PATH.include?( dir.to_s )
	end
}

