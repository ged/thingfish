# -*- encoding: utf-8 -*-
# stub: thingfish 0.5.0.pre20161114092630 ruby lib

Gem::Specification.new do |s|
  s.name = "thingfish"
  s.version = "0.5.0.pre20161114092630"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Michael Granger", "Mahlon E. Smith"]
  s.cert_chain = ["certs/ged.pem"]
  s.date = "2016-11-14"
  s.description = "Thingfish is a extensible, web-based digital asset manager. It can be used to\nstore chunks of data on the network in an application-independent way, link the\nchunks together with metadata, and then search for the chunk you need later and\nfetch it, all through a REST API."
  s.email = ["ged@FaerieMUD.org", "mahlon@martini.nu"]
  s.executables = ["thingfish"]
  s.extra_rdoc_files = ["History.rdoc", "Manifest.txt", "README.rdoc", "History.rdoc", "README.rdoc"]
  s.files = [".simplecov", "ChangeLog", "Gemfile", "History.rdoc", "LICENSE", "Manifest.txt", "Procfile", "README.rdoc", "Rakefile", "bin/thingfish", "etc/mongrel2-config.rb", "etc/thingfish.conf.example", "lib/strelka/app/metadata.rb", "lib/strelka/httprequest/metadata.rb", "lib/thingfish.rb", "lib/thingfish/behaviors.rb", "lib/thingfish/datastore.rb", "lib/thingfish/datastore/memory.rb", "lib/thingfish/handler.rb", "lib/thingfish/metastore.rb", "lib/thingfish/metastore/memory.rb", "lib/thingfish/mixins.rb", "lib/thingfish/processor.rb", "lib/thingfish/processor/sha256.rb", "lib/thingfish/spechelpers.rb", "spec/data/APIC-1-image.mp3", "spec/data/APIC-2-images.mp3", "spec/data/PIC-1-image.mp3", "spec/data/PIC-2-images.mp3", "spec/helpers.rb", "spec/spec.opts", "spec/thingfish/datastore/memory_spec.rb", "spec/thingfish/datastore_spec.rb", "spec/thingfish/handler_spec.rb", "spec/thingfish/metastore/memory_spec.rb", "spec/thingfish/metastore_spec.rb", "spec/thingfish/mixins_spec.rb", "spec/thingfish/processor/sha256_spec.rb", "spec/thingfish/processor_spec.rb", "spec/thingfish_spec.rb"]
  s.homepage = "https://thing.fish/"
  s.licenses = ["BSD-3-Clause", "BSD"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.required_ruby_version = Gem::Requirement.new(">= 2.0.0")
  s.rubygems_version = "2.5.1"
  s.summary = "Thingfish is a extensible, web-based digital asset manager"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<strelka>, ["~> 0.9"])
      s.add_runtime_dependency(%q<mongrel2>, ["~> 0.46"])
      s.add_development_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_development_dependency(%q<hoe-deveiate>, ["~> 0.8"])
      s.add_development_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<hoe>, ["~> 3.15"])
    else
      s.add_dependency(%q<strelka>, ["~> 0.9"])
      s.add_dependency(%q<mongrel2>, ["~> 0.46"])
      s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
      s.add_dependency(%q<hoe-deveiate>, ["~> 0.8"])
      s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
      s.add_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<hoe>, ["~> 3.15"])
    end
  else
    s.add_dependency(%q<strelka>, ["~> 0.9"])
    s.add_dependency(%q<mongrel2>, ["~> 0.46"])
    s.add_dependency(%q<hoe-mercurial>, ["~> 1.4"])
    s.add_dependency(%q<hoe-deveiate>, ["~> 0.8"])
    s.add_dependency(%q<hoe-highline>, ["~> 0.2"])
    s.add_dependency(%q<simplecov>, ["~> 0.7"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<hoe>, ["~> 3.15"])
  end
end
