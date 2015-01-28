# -*- ruby -*-
#encoding: utf-8
# vim: set nosta noet ts=4 sw=4 ft=ruby:

require 'time'
require 'thingfish'
require 'rspec'


### RSpec helper functions.
module Thingfish::SpecHelpers

	module Constants
		TEST_APPID        = 'thingfish-test'
		TEST_SEND_SPEC    = 'tcp://127.0.0.1:9999'
		TEST_RECV_SPEC    = 'tcp://127.0.0.1:9998'

		UUID_PATTERN      = /[[:xdigit:]]{8}(?:-[[:xdigit:]]{4}){3}-[[:xdigit:]]{12}/i

		TEST_UUID         = 'E5DFEEAB-3525-4F14-B4DB-2772D0B9987F'

		TEST_TEXT_DATA    = "Pork sausage. Pork! Sausage!".b
		TEST_TEXT_DATA_IO = StringIO.new( TEST_TEXT_DATA )
		TEST_PNG_DATA     = ("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMA" +
		                     "AQAABQABDQottAAAAABJRU5ErkJggg==").unpack('m').first
		TEST_PNG_DATA_IO  = StringIO.new( TEST_PNG_DATA )

		TEST_METADATA = [
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 1072,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "application/rtf",
			 "created"       => Time.parse('2010-10-14 00:08:21 UTC'),
			 "title"         => "How to use the Public folder.rtf"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 832604,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:54 UTC'),
			 "title"         => "IMG_0316.JPG"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 2253642,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:49 UTC'),
			 "title"         => "IMG_0544.JPG"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 694785,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:52 UTC'),
			 "title"         => "IMG_0552.JPG"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 1579773,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:56 UTC'),
			 "title"         => "IMG_0748.JPG"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 6464493,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-10-14 05:05:23 UTC'),
			 "title"         => "IMG_1700.JPG"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 388727,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-12-28 01:23:27 UTC'),
			 "title"         => "IMG_3553.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 1354,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "text/plain",
			 "created"       => Time.parse('2013-09-09 15:43:31 UTC'),
			 "title"         => "agilemanifesto.txt"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 3059035,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2013-04-18 00:25:56 UTC'),
			 "title"         => "bacon.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 71860,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:57 UTC'),
			 "title"         => "boom.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 2115410,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "audio/mp3",
			 "created"       => Time.parse('2013-09-09 15:42:49 UTC'),
			 "title"         => "craigslist_erotica.mp3"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 377445,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2012-02-09 17:06:44 UTC'),
			 "title"         => "cubes.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 240960,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "audio/mp3",
			 "created"       => Time.parse('2013-09-09 15:42:58 UTC'),
			 "title"         => "gay_clowns.mp3"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 561792,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2011-09-06 20:10:57 UTC'),
			 "title"         => "grass2.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 1104950,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/jpeg",
			 "created"       => Time.parse('2013-09-09 15:37:25 UTC'),
			 "title"         => "joss.jpg"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 163,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "text/plain",
			 "created"       => Time.parse('2013-01-23 07:52:44 UTC'),
			 "title"         => "macbook.txt"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 2130567,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/png",
			 "created"       => Time.parse('2012-03-15 05:15:07 UTC'),
			 "title"         => "marbles.png"},
			{"useragent"     => "ChunkersTheClown v2.0",
			 "extent"        => 8971,
			 "uploadaddress" => "127.0.0.1",
			 "format"        => "image/gif",
			 "created"       => Time.parse('2013-01-15 19:15:35 UTC'),
			 "title"         => "trusttom.GIF"}
		].freeze

	end # module Constants

	include Constants


	# Load fixture data from the ThingFish spec data directory
	FIXTURE_DIR = Pathname( __FILE__ ).dirname.parent.parent + 'spec/data'


	RSpec::Matchers.define :be_a_uuid do |expected|
		match do |actual|
			actual =~ UUID_PATTERN
		end
	end


	### Load and return the data from the fixture with the specified +filename+.
	def fixture_data( filename )
		fixture = FIXTURE_DIR + filename
		return fixture.open( 'r', encoding: 'binary' )
	end

end # Thingfish::SpecHelpers


