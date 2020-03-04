# -*- ruby -*-
# vim: set nosta noet ts=4 sw=4:
# frozen_string_literal: true

#
# This script generates a Mongrel2 configuration database suitable for
# getting a Thingfish handler running.
#
# Load it with:
#
#     $ m2sh.rb -c mongrel2.sqlite load examples/mongrel2-config.rb
#
# Afterwards, ensure the path to the mongrel2.sqlite file is in your
# thingfish.conf:
#
#     mongrel2:
#       configdb: /path/to/mongrel2.sqlite
#
# ... and start the mongrel2 daemon:
#
#     $ mongrel2 /path/to/mongrel2.sqlite thingfish
#
# In production use, you'll likely want to mount the Thingfish handler
# within the URI space of an existing Mongrel2 environment.
#

require 'mongrel2'
require 'mongrel2/config/dsl'

server 'thingfish' do
	name         'Thingfish'
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

setting 'zeromq.threads', 1
setting 'limits.content_length', 250_000
setting 'server.daemonize', false
setting 'upload.temp_store', 'var/uploads/mongrel2.upload.XXXXXX'

mkdir_p 'var/uploads'
mkdir_p 'run'
mkdir_p 'logs'

