# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
#encoding: utf-8

# The Mongrel config used by the examples. Load it with:
#
#   m2sh.rb -c examples/mongrel2.sqlite load examples/gen-config.rb
#

require 'mongrel2'
require 'mongrel2/config/dsl'


# samples server
server 'thingfish' do

	name         'Thingfish Examples'
	default_host 'localhost'

	access_log   'logs/access.log'
	error_log    'logs/error.log'
	chroot       ''
	pid_file     'run/mongrel2.pid'

	bind_addr    '0.0.0.0'
	port         3474

	xrequest     '/usr/local/lib/mongrel2/filters/sendfile.so'

	host 'localhost' do
		route '/', handler( 'tcp://127.0.0.1:9900', 'thingfish' )
	end

end

setting "zeromq.threads", 1

setting 'limits.content_length', 250_000
setting 'server.daemonize', false
setting 'upload.temp_store', 'var/uploads/mongrel2.upload.XXXXXX'

mkdir_p 'var/uploads'
mkdir_p 'run'
mkdir_p 'logs'

