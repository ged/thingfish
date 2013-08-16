#!/usr/bin/env rake
#encoding: utf-8

require 'pathname'
require 'hoe'

# Directory to keep benchmarks around in
BASEDIR      = Pathname( __FILE__ ).dirname
BENCHMARKDIR = BASEDIR + 'benchmarks'
MISCDIR      = BASEDIR + 'misc'
TESTIMAGE    = MISCDIR + 'testimage.jpg'


Hoe.plugin :mercurial
Hoe.plugin :signing
Hoe.plugin :manualgen

Hoe.plugins.delete :rubyforge


hoespec = Hoe.spec 'thingfish' do
	self.readme_file = 'README.rdoc'
	self.history_file = 'History.rdoc'
	self.extra_rdoc_files = Rake::FileList[ '*.rdoc' ]

	self.developer 'Michael Granger', 'ged@FaerieMUD.org'
	self.developer 'Mahlon E. Smith', 'mahlon@martini.nu'
	self.license "BSD"

	self.dependency 'pluggability',    '~> 1.0'
	self.dependency 'loggability',     '~> 1.0'
	self.dependency 'configurability', '~> 2.1'
	self.dependency 'pg',              '~> 0.16'
	self.dependency 'strelka',         '~> 0.6'
	self.dependency 'sequel',          '~> 4.0'
	self.dependency 'sequel_pg',       '~> 1.6'

	self.dependency 'hoe-deveiate',  '~> 0.3',  :development

	self.require_ruby_version( '>=2.0.0' )

	self.hg_sign_tags = true if self.respond_to?( :hg_sign_tags= )
	self.rdoc_locations << "deveiate:/usr/local/www/public/code/#{remote_rdoc_dir}"
end

ENV['VERSION'] ||= hoespec.spec.version.to_s

task 'hg:precheckin' => [ 'ChangeLog', :check_manifest, :check_history, :spec ]


