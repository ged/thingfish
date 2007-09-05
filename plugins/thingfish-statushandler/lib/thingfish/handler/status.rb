#!/usr/bin/ruby
#
# Output detailed server status -- this is an elaboration of Mongrel::StatusHandler.
#
# == Synopsis
#
#   # thingfish.conf
#   plugins:
#     handlers:
# 		- status:
# 			uris: /server-status
# 			stat_uris: [/, /metadata, /admin]
# 
# == Version
#
#  $Id$
#
# == Authors
# * Zed Shaw <zedshaw at zedshaw.com> wrote Mongrel::StatusHandler
#
# * Michael Granger <mgranger@laika.com> cluttered it up with this crap
#
# :include: LICENSE
#
#---
#
# Please see the file LICENSE in the 'docs' directory for licensing details.
#

require 'thingfish/mixins'
require 'thingfish/handler'
require 'thingfish/constants'
require 'mongrel/stats'
require 'mongrel/handlers'


### Add an attribute reader +name+
class Mongrel::Stats
	attr_reader :name
end

### Add some attribute readers an an #each_stat method to the 
### default Mongrel StatisticsFilter
class Mongrel::StatisticsFilter
	include ThingFish::Loggable
	
	STATS = [
	 	:processors,
		:reqsize,
		:headcount,
		:respsize,
		:interreq,
	  ]
	
	attr_reader( *STATS )

	
	### Pass each stat to the supplied block in succession.
	def each_stat
		STATS.each do |statname|
			yield( self.send(statname) )
		end
	end
	
	### Gather sampled statistics about the request
	def process( request, response )
		if rand( @sample_rate ) + 1 == @sample_rate
			self.log.debug { "Sampling stats for %s" % [request.uri] }
			@processors.sample( self.listener.workers.list.length )
			@headcount.sample( request.headers.length )
			@reqsize.sample( request.body.length / 1024.0 )
			@respsize.sample( (response.get_content_length + response.headers.to_s.length) / 1024.0 )
		end
		@interreq.tick
	end

end


### Output a quick inspection page
class ThingFish::StatusHandler < ThingFish::Handler
	include ThingFish::Loggable,
	        ThingFish::StaticResourcesHandler,
	        ThingFish::Constants,
	        ThingFish::ResourceLoader


	# SVN Revision
	SVNRev = %q$Rev$

	# SVN Id
	SVNId = %q$Id$

	HANDLER_DEFAULTS = {
		'resource_dir'	=> nil, # Use the default
		'template_name' => 'index.rhtml',
		'stat_uris'		=> [],
	}


	#################################################################
	###	I N S T A N C E   M E T H O D S
	#################################################################

	### Create a new StatusHandler. Installs statistics filters in the URIs specified
	### in <tt>options[:stats_filters]</tt>.
	def initialize( options={} )
		@filters = {}
		super( HANDLER_DEFAULTS.merge(options) )
	end


	######
	public
	######

	# The list of statistics filters this handler registered with its listener (if any)
	attr_reader :filters
	
	
	### Handler API: Send GET response
	def handle_get_request( request, response )
		self.log.debug "Handling GET request"
		generate_output( request, response ) if request.path_info == ''
	end
	
	
	### Handler API: Send HEAD response
	def handle_head_request( request, response )
		self.log.debug "Handling HEAD request"
		generate_output( request, response, false ) if request.path_info == ''	
	end
	
	
	### Create status content and write to response.
	def generate_output( request, response, send_body=true )
		response.status = HTTP::OK

		if request.accepts?( 'text/html' )
			listener = self.listener
			template = self.get_erb_resource( @options['template_name'] )

			response.headers[:content_type] = 'text/html'
			response.body = template.result( binding() ) if send_body
		else
			response.headers[:content_type] = RUBY_MIMETYPE
			response.body = extract_statistics() if send_body
		end
	end


	### Extract a Hash of statistics from each configured filter and return it.
	def extract_statistics
		return @listener.classifier.handler_map.inject({}) do |hash, pair|
			uri = pair.first

			if @filters.key?( uri )
				subhash = {}
				@filters[uri].each_stat do |stat|
					subhash[ stat.name ] = {
						:sum   => stat.sum,
						:sumsq => stat.sumsq,
						:n     => stat.n,
						:mean  => stat.mean,
						:sd    => stat.sd,
						:min   => stat.min,
						:max   => stat.max,
					}
				end
				hash[uri] = subhash
			else
				hash[uri] = nil
			end

			hash
		end
	end
	
	
	### Overload the listener writer to also register stats filters as soon as the
	### handler is registered.
	def listener=( listener )
		self.register_stats_filters( listener, @options['stat_uris'] )
		super
	end


	### Return the HTML fragment that should be used to link to this handler.
	def make_index_content( uri )
		tmpl = self.get_erb_resource( "index_content.rhtml" )
		return tmpl.result( binding() )
	end


	#########
	protected
	#########

	### Register a Mongrel::StatisticsFilter at eash of the +uris+ specified.
	def register_stats_filters( listener, uris )
		return unless uris && uris.respond_to?( :uniq )
		uris.uniq.each do |uri|
			filter = Mongrel::StatisticsFilter.new( :sample_rate => 3 )
			self.log.debug "Registering stats filter for %s at %p" %
				[ self.class.name, uri ]
			listener.register( uri, filter, true )
			
			@filters[uri] = filter
		end
	end

end # class ThingFish::StatusHandler

# vim: set nosta noet ts=4 sw=4:
