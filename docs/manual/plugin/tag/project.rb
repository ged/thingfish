# 
# Project metadata plugin for the ThingFish manual
# 

BEGIN {
	require 'pathname'

	basedir = Pathname.new( __FILE__.sub(%r{/docs/manual/plugin/tag/.*$}, '') )
	libdir = basedir + 'lib'
	
	$LOAD_PATH.unshift( libdir.to_s ) unless $LOAD_PATH.include?( libdir.to_s )
}

require 'thingfish'


# Includes a file verbatim. All HTML special characters are escaped.
class ProjectTag < Tags::DefaultTag

	infos( :name => 'Tag/Project',
		:author => "Monkeys",
		:summary => "Insert one or more bits of metadata about the project"
	)

	param 'key', nil, %q{The key of the bit of metadata to insert}
	param 'html', true, %q{Whether or not to wrap a <span> around the inserted } +
		%q{value with an approrpriate CSS class}
	param 'escapeHTML', true, %q{Whether or not to escape HTML characters } +
		%q{in the metadata value.}

	set_mandatory 'key', true

	register_tag 'project'


	### Process the specified +tag+ in the given +chain+.
	def process_tag( tag, chain )
		key = param( 'key' )
		meth = self.method( "get_project_#{key}" ) or
			raise "No such key '#{key}'"
			
		rval = meth.call( tag, chain )
		rval = escape_html( rval ) if param('escapeHTML')
		
		if param('html')
			return %q{<span class="project-%s">%s</span>} %
				[ key.gsub(/[^a-z]+/, '-'), rval ]
		else
			return rval
		end
	rescue RuntimeError => err
		log( :error ) { "%s: %s" % [ err.class.name, err.message ] }
	end



	#########
	protected
	#########

	### Return the project version as a string.
	def get_project_version( tag, chain )
		return ThingFish::VERSION
	end
	



	#######
	private
	#######

	### Return the given +content+ with any HTML entities escaped.
	def escape_html( content )
		content.
			gsub( /&/n, '&amp;' ).
			gsub( /\"/n, '&quot;' ).
			gsub( />/n, '&gt;' ).
			gsub( /</n, '&lt;' )
	end

end
