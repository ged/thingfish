#!/usr/bin/env ruby -w

require 'pp'

MIMETYPES = {
	'.png' => 'image/png',
	'.jpg' => 'image/jpeg',
	'.txt' => 'text/plain',
	'.mp3' => 'audio/mp3',
	'.rtf' => 'application/rtf',
	'.gif' => 'image/gif',
}

ARGV.each do |file|

	type = File.extname( file ).downcase

	metadata = {
		'useragent'     => 'ChunkersTheClown v2.0',
		'extent'        => File.size( file ),
		'uploadaddress' => '127.0.0.1',
		'format'        => MIMETYPES[ type ],
		'created'       => File.mtime( file ).gmtime.to_s,
		'title'         => file,
	}

	pp metadata

end

