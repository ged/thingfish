# -*- ruby -*-
# frozen_string_literal: true

require 'strelka/discovery'

Strelka::Discovery.register_apps(
	'thingfish' => 'thingfish/handler.rb'
)

