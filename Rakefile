require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "commerce-bank-client"
    gem.summary = %Q{CBC is a client for Commerce Bank's website.}
    gem.email = "alexmchale@gmail.com"
    gem.homepage = "http://github.com/alexmchale/commerce-bank-client"
    gem.authors = ["Alex McHale"]
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install technicalpickles-jeweler -s http://gems.github.com"
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = 'commerce-bank-client'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = false
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :verify_committed do
  abort "This project has not been fully committed." unless `git status | grep "nothing to commit"` != ''
end

task :patch => [ :verify_committed, :test, "version:bump:patch", :build, :install, :release ]
task :minor => [ :verify_committed, :test, "version:bump:minor", :build, :install, :release ]
task :major => [ :verify_committed, :test, "version:bump:major", :build, :install, :release ]

task :default => :test
