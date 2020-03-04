# -*- encoding: utf-8 -*-
# stub: thingfish 0.8.0.pre.20200304144036 ruby lib

Gem::Specification.new do |s|
  s.name = "thingfish".freeze
  s.version = "0.8.0.pre.20200304144036"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://todo.sr.ht/~ged/thingfish", "changelog_uri" => "https://thing.fish/docs/History_md.html", "documentation_uri" => "https://thing.fish/docs/", "homepage_uri" => "https://thing.fish", "source_uri" => "https://hg.sr.ht/~ged/thingfish" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Michael Granger".freeze, "Mahlon E. Smith".freeze]
  s.date = "2020-03-04"
  s.description = "Thingfish is a extensible, web-based digital asset manager. It can be used to store chunks of data on the network in an application-independent way, link the chunks together with metadata, and then search for the chunk you need later and fetch it, all through a REST API.".freeze
  s.email = ["ged@FaerieMUD.org".freeze, "mahlon@martini.nu".freeze]
  s.executables = ["thingfish".freeze]
  s.files = [".simplecov".freeze, "History.md".freeze, "LICENSE".freeze, "README.md".freeze, "Rakefile".freeze, "bin/thingfish".freeze, "lib/strelka/app/metadata.rb".freeze, "lib/strelka/apps.rb".freeze, "lib/strelka/httprequest/metadata.rb".freeze, "lib/thingfish.rb".freeze, "lib/thingfish/behaviors.rb".freeze, "lib/thingfish/datastore.rb".freeze, "lib/thingfish/datastore/memory.rb".freeze, "lib/thingfish/handler.rb".freeze, "lib/thingfish/metastore.rb".freeze, "lib/thingfish/metastore/memory.rb".freeze, "lib/thingfish/mixins.rb".freeze, "lib/thingfish/processor.rb".freeze, "lib/thingfish/processor/sha256.rb".freeze, "lib/thingfish/spechelpers.rb".freeze, "spec/data/APIC-1-image.mp3".freeze, "spec/data/APIC-2-images.mp3".freeze, "spec/data/PIC-1-image.mp3".freeze, "spec/data/PIC-2-images.mp3".freeze, "spec/helpers.rb".freeze, "spec/spec.opts".freeze, "spec/thingfish/datastore/memory_spec.rb".freeze, "spec/thingfish/datastore_spec.rb".freeze, "spec/thingfish/handler_spec.rb".freeze, "spec/thingfish/metastore/memory_spec.rb".freeze, "spec/thingfish/metastore_spec.rb".freeze, "spec/thingfish/mixins_spec.rb".freeze, "spec/thingfish/processor/sha256_spec.rb".freeze, "spec/thingfish/processor_spec.rb".freeze, "spec/thingfish_spec.rb".freeze]
  s.homepage = "https://thing.fish".freeze
  s.licenses = ["BSD-3-Clause".freeze]
  s.rubygems_version = "3.1.2".freeze
  s.summary = "Thingfish is a extensible, web-based digital asset manager.".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<strelka>.freeze, ["~> 0.14"])
    s.add_development_dependency(%q<rake-deveiate>.freeze, ["~> 0.10"])
    s.add_development_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
    s.add_development_dependency(%q<simplecov>.freeze, ["~> 0.18"])
  else
    s.add_dependency(%q<strelka>.freeze, ["~> 0.14"])
    s.add_dependency(%q<rake-deveiate>.freeze, ["~> 0.10"])
    s.add_dependency(%q<rdoc-generator-fivefish>.freeze, ["~> 0.4"])
    s.add_dependency(%q<simplecov>.freeze, ["~> 0.18"])
  end
end
