#!/usr/bin/env ruby

load './loadpath.rb'
require 'thingfish/config'
require 'thingfish/metastore'

dd = Pathname.new( '/tmp/thingfish' )
sd = dd + 'spool'

ThingFish.logger.level = Logger::INFO

ms = ThingFish::MetaStore.create( 'sequel', dd, sd, 
	:sequel_connect => 'sqlite:////tmp/thingfish/metastore.db' )
pgms = ThingFish::MetaStore.create( 'sequel', dd, sd, 
	:sequel_connect => 'postgres://thingfish@localhost/db01' )

pgms.migrate_from( ms )

