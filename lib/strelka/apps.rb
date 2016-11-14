# -*- ruby -*-
#encoding: utf-8

require 'strelka/discovery'

Strelka::Discovery.register_apps(
	'thingfish' => 'thingfish/handler.rb'
)

