require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new("commerce-bank-client", "1.2.0") do |p|

  p.description              = "An interface to the Commerce Bank website (https://banking.commercebank.com)."
  p.url                      = "http://github.com/alexmchale/commerce-bank-client"
  p.author                   = "Alex McHale"
  p.email                    = "alexmchale@gmail.com"
  p.ignore_pattern           = %w( tmp/* script/* )
  p.runtime_dependencies     = [ "hpricot", "andand", "htmlentities" ]
  p.development_dependencies = []
  p.require_signed           = true
  p.use_sudo                 = false

end
