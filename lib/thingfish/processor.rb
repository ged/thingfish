# -*- ruby -*-
#encoding: utf-8

require 'pluggability'
require 'strelka/httprequest/acceptparams'

require 'thingfish' unless defined?( Thingfish )


# Thingfish asset processor base class.
class Thingfish::Processor
	extend Pluggability


	plugin_prefixes 'thingfish/processor'


	### Get/set the list of media types this processor can handle.
	def self::handled_types( *mediatypes )
		if mediatypes.empty?
			@handled_types ||= []
		else
			@handled_types = mediatypes.collect do |type|
				Strelka::HTTPRequest::MediaType.parse(type)
			end
		end

		return @handled_types
	end


	### Filter hook for request, pass to processor if it is able to
	### handle the +request+ content type.
	def process_request( request )
		if self.handled_type?( request.content_type )
			on_request( request )
		end
	end


	### Process the data and/or metadata in the +request+.
	def on_request( request )
		# No-op by default
	end


	### Filter hook for response, pass to processor if it is able to
	### handle the +response+ content type.
	def process_response( response )
		if self.handled_type?( response.content_type )
			on_response( response )
		end
	end


	### Process the data and/or metadata in the +response+.
	def on_response( response )
		# No-op by default
	end


	### Returns +true+ if the given media +type+ is one the processor handles.
	def handled_type?( type )
		return true if self.class.handled_types.empty?
		self.class.handled_types.find {|handled_type| type =~ handled_type }
	end
	alias_method :is_handled_type?, :handled_type?


end # class Thingfish::Processor

