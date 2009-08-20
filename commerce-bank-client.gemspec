# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{commerce-bank-client}
  s.version = "0.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alex McHale"]
  s.date = %q{2009-08-20}
  s.email = %q{alexmchale@gmail.com}
  s.extra_rdoc_files = [
    "README.markdown"
  ]
  s.files = [
    ".gitignore",
     "README.markdown",
     "Rakefile",
     "VERSION.yml",
     "commerce-bank-client.gemspec",
     "lib/commercebank.rb",
     "lib/commercebank/monkey.rb",
     "test/commerce_bank_client_test.rb",
     "test/monkeypatch_test.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/alexmchale/commerce-bank-client}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{CBC is a client for Commerce Bank's website.}
  s.test_files = [
    "test/test_helper.rb",
     "test/monkeypatch_test.rb",
     "test/commerce_bank_client_test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
