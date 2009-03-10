# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{commerce-bank-client}
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Alex McHale"]
  s.date = %q{2009-03-10}
  s.email = %q{alexmchale@gmail.com}
  s.extra_rdoc_files = ["README.markdown"]
  s.files = ["VERSION.yml", "README.markdown", "lib/commercebank.rb", "lib/commercebank", "lib/commercebank/monkey.rb", "lib/commercebank/gmail.rb", "lib/commercebank/appconfig.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/alexmchale/commerce-bank-client}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{CBC is a client for Commerce Bank's website.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json>, [">= 1.1.3"])
      s.add_runtime_dependency(%q<andand>, [">= 1.3.1"])
    else
      s.add_dependency(%q<json>, [">= 1.1.3"])
      s.add_dependency(%q<andand>, [">= 1.3.1"])
    end
  else
    s.add_dependency(%q<json>, [">= 1.1.3"])
    s.add_dependency(%q<andand>, [">= 1.3.1"])
  end
end
