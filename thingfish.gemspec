# -*- encoding: utf-8 -*-
# stub: thingfish 0.7.0.pre20170119154654 ruby lib

Gem::Specification.new do |s|
  s.name = "thingfish".freeze
  s.version = "0.7.0.pre20170119154654"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze, "Mahlon E. Smith".freeze]
  s.cert_chain = ["certs/ged.pem".freeze]
  s.date = "2017-01-19"
  s.description = "Thingfish is a extensible, web-based digital asset manager. It can be used to\nstore chunks of data on the network in an application-independent way, link the\nchunks together with metadata, and then search for the chunk you need later and\nfetch it, all through a REST API.".freeze
  s.email = ["ged@FaerieMUD.org".freeze, "mahlon@martini.nu".freeze]
  s.executables = ["thingfish".freeze]
  s.extra_rdoc_files = ["History.rdoc".freeze, "Manifest.txt".freeze, "README.rdoc".freeze, "History.rdoc".freeze, "README.rdoc".freeze]
  s.files = [".simplecov".freeze, "ChangeLog".freeze, "Gemfile".freeze, "History.rdoc".freeze, "LICENSE".freeze, "Manifest.txt".freeze, "Procfile".freeze, "README.rdoc".freeze, "Rakefile".freeze, "bin/thingfish".freeze, "etc/mongrel2-config.rb".freeze, "etc/thingfish.conf.example".freeze, "lib/strelka/app/metadata.rb".freeze, "lib/strelka/apps.rb".freeze, "lib/strelka/httprequest/metadata.rb".freeze, "lib/thingfish.rb".freeze, "lib/thingfish/behaviors.rb".freeze, "lib/thingfish/datastore.rb".freeze, "lib/thingfish/datastore/memory.rb".freeze, "lib/thingfish/handler.rb".freeze, "lib/thingfish/metastore.rb".freeze, "lib/thingfish/metastore/memory.rb".freeze, "lib/thingfish/mixins.rb".freeze, "lib/thingfish/processor.rb".freeze, "lib/thingfish/processor/sha256.rb".freeze, "lib/thingfish/spechelpers.rb".freeze, "spec/data/APIC-1-image.mp3".freeze, "spec/data/APIC-2-images.mp3".freeze, "spec/data/PIC-1-image.mp3".freeze, "spec/data/PIC-2-images.mp3".freeze, "spec/helpers.rb".freeze, "spec/spec.opts".freeze, "spec/thingfish/datastore/memory_spec.rb".freeze, "spec/thingfish/datastore_spec.rb".freeze, "spec/thingfish/handler_spec.rb".freeze, "spec/thingfish/metastore/memory_spec.rb".freeze, "spec/thingfish/metastore_spec.rb".freeze, "spec/thingfish/mixins_spec.rb".freeze, "spec/thingfish/processor/sha256_spec.rb".freeze, "spec/thingfish/processor_spec.rb".freeze, "spec/thingfish_spec.rb".freeze]
  s.homepage = "https://thing.fish".freeze
  s.licenses = ["BSD-3-Clause".freeze, "BSD".freeze]
  s.rdoc_options = ["--main".freeze, "README.rdoc".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0".freeze)
  s.rubygems_version = "2.6.8".freeze
  s.summary = "Thingfish is a extensible, web-based digital asset manager".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<strelka>.freeze, ["~> 0.14"])
      s.add_development_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
      s.add_development_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>.freeze, ["~> 3.15"])
    else
      s.add_dependency(%q<strelka>.freeze, ["~> 0.14"])
      s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
      s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
      s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
      s.add_dependency(%q<hoe>.freeze, ["~> 3.15"])
    end
  else
    s.add_dependency(%q<strelka>.freeze, ["~> 0.14"])
    s.add_dependency(%q<hoe-mercurial>.freeze, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>.freeze, ["~> 0.8"])
    s.add_dependency(%q<hoe-highline>.freeze, ["~> 0.2"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.7"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 4.0"])
    s.add_dependency(%q<hoe>.freeze, ["~> 3.15"])
  end
end
