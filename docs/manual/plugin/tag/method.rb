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


# Reference to an API method
class MethodReferenceTag < Tags::DefaultTag

	infos( :name => 'Tag/Method',
		:author => "Monkeys",
		:summary => "Insert a link to a method"
	)

	param 'name', nil, %q{The fully-qualified method name in the form Class#method}
	param 'full', false, %q{Whether to make the text include the fully-qualified } +
	  %q{method name, including the class or module.}

	set_mandatory 'name', true

	register_tag 'method'


	### Process the specified +tag+ in the given +chain+.
	def process_tag( tag, chain )
		name = param( 'name' ).strip

		unless name =~ /^([a-z][\w:]+)(::|\.|#)([a-z]\w+)$/i
			raise "Malformed method %p" % [name]
		end
		
		mod, qualifier, meth = $1, $2, $3
		mtype = qualifier == '#' ? 'instance' : 'class'

		# Just return it in textile markup for now
		return %{<code class="method #{mtype}-method">#{meth}</code>}
	rescue RuntimeError => err
		log( :error ) { "(In %p) %s: %s" % 
			[ chain.last.node_info, err.class.name, err.message ] }
	end

end
