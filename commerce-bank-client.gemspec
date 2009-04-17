# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{commerce-bank-client}
  s.version = "0.9.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alex McHale"]
  s.date = %q{2009-04-17}
  s.email = %q{alexmchale@gmail.com}
  s.extra_rdoc_files = [
    "README.markdown"
  ]
  s.files = [
    "README.markdown",
    "Rakefile",
    "VERSION.yml",
    "lib/commercebank.rb",
    "lib/commercebank/monkey.rb",
    "test/commerce_bank_client_test.rb",
    "test/monkeypatch_test.rb",
    "test/test_helper.rb"
  ]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/alexmchale/commerce-bank-client}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{CBC is a client for Commerce Bank's website.}
  s.test_files = [
    "test/monkeypatch_test.rb",
    "test/test_helper.rb",
    "test/commerce_bank_client_test.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
