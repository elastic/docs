# -*- encoding: utf-8 -*-
# stub: asciidoctor 1.5.8 ruby lib

Gem::Specification.new do |s|
  s.name = "asciidoctor".freeze
  s.version = "1.5.8"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/asciidoctor/asciidoctor/issues", "changelog_uri" => "https://github.com/asciidoctor/asciidoctor/blob/master/CHANGELOG.adoc", "mailing_list_uri" => "http://discuss.asciidoctor.org", "source_code_uri" => "https://github.com/asciidoctor/asciidoctor" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Dan Allen".freeze, "Sarah White".freeze, "Ryan Waldron".freeze, "Jason Porter".freeze, "Nick Hengeveld".freeze, "Jeremy McAnally".freeze]
  s.date = "2018-10-28"
  s.description = "A fast, open source text processor and publishing toolchain, written in Ruby, for converting AsciiDoc content to HTML5, DocBook 5 (or 4.5) and other formats.".freeze
  s.email = ["dan.j.allen@gmail.com".freeze]
  s.executables = ["asciidoctor".freeze, "asciidoctor-safe".freeze]
  s.extra_rdoc_files = ["CHANGELOG.adoc".freeze, "CONTRIBUTING.adoc".freeze, "LICENSE".freeze]
  s.files = ["CHANGELOG.adoc".freeze, "CONTRIBUTING.adoc".freeze, "LICENSE".freeze, "bin/asciidoctor".freeze, "bin/asciidoctor-safe".freeze]
  s.homepage = "http://asciidoctor.org".freeze
  s.licenses = ["MIT".freeze]
  s.rdoc_options = ["--charset=UTF-8".freeze]
  s.rubygems_version = "2.7.6".freeze
  s.summary = "An implementation of the AsciiDoc text processor and publishing toolchain in Ruby".freeze

  s.installed_by_version = "2.7.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<asciimath>.freeze, ["~> 1.0.0"])
      s.add_development_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
      s.add_development_dependency(%q<cucumber>.freeze, ["~> 2.4.0"])
      s.add_development_dependency(%q<erubis>.freeze, ["~> 2.7.0"])
      s.add_development_dependency(%q<haml>.freeze, ["~> 5.0.0"])
      s.add_development_dependency(%q<nokogiri>.freeze, ["~> 1.8.5"])
      s.add_development_dependency(%q<rake>.freeze, ["~> 10.0.0"])
      s.add_development_dependency(%q<rspec-expectations>.freeze, ["~> 2.14.0"])
      s.add_development_dependency(%q<slim>.freeze, ["~> 4.0.0"])
      s.add_development_dependency(%q<tilt>.freeze, ["~> 2.0.0"])
      s.add_development_dependency(%q<minitest>.freeze, ["~> 5.3.0"])
    else
      s.add_dependency(%q<asciimath>.freeze, ["~> 1.0.0"])
      s.add_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
      s.add_dependency(%q<cucumber>.freeze, ["~> 2.4.0"])
      s.add_dependency(%q<erubis>.freeze, ["~> 2.7.0"])
      s.add_dependency(%q<haml>.freeze, ["~> 5.0.0"])
      s.add_dependency(%q<nokogiri>.freeze, ["~> 1.8.5"])
      s.add_dependency(%q<rake>.freeze, ["~> 10.0.0"])
      s.add_dependency(%q<rspec-expectations>.freeze, ["~> 2.14.0"])
      s.add_dependency(%q<slim>.freeze, ["~> 4.0.0"])
      s.add_dependency(%q<tilt>.freeze, ["~> 2.0.0"])
      s.add_dependency(%q<minitest>.freeze, ["~> 5.3.0"])
    end
  else
    s.add_dependency(%q<asciimath>.freeze, ["~> 1.0.0"])
    s.add_dependency(%q<coderay>.freeze, ["~> 1.1.0"])
    s.add_dependency(%q<cucumber>.freeze, ["~> 2.4.0"])
    s.add_dependency(%q<erubis>.freeze, ["~> 2.7.0"])
    s.add_dependency(%q<haml>.freeze, ["~> 5.0.0"])
    s.add_dependency(%q<nokogiri>.freeze, ["~> 1.8.5"])
    s.add_dependency(%q<rake>.freeze, ["~> 10.0.0"])
    s.add_dependency(%q<rspec-expectations>.freeze, ["~> 2.14.0"])
    s.add_dependency(%q<slim>.freeze, ["~> 4.0.0"])
    s.add_dependency(%q<tilt>.freeze, ["~> 2.0.0"])
    s.add_dependency(%q<minitest>.freeze, ["~> 5.3.0"])
  end
end
