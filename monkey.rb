require 'rubygems'
require 'pp'
require 'andand'
require 'cgi'
require 'yaml'

class Array
  def binary
    map {|e| yield(e) ? [e, nil] : [nil, e]}.transpose.map {|a| a.compact}
  end

  def paramify
    hash = Hash.new

    hash.merge! pop if last.kind_of? Hash
    each {|e| hash[e] = true}

    hash
  end
end

class Object
  def to_cents
    (to_s.gsub(/[^-.0-9]/, '').to_f * 100).to_i
  end

  def to_dollars(*options)
    options = options.paramify

    plus = options[:show_plus] ? '+' : ''
    minus = options[:hide_minus] ? '' : '-'
    sign = to_i >= 0 ? plus : minus

    ("%s%0.2f" % [ sign, to_i.abs / 100.0 ]).commify
  end
end

class Date
  def days_in_month
    (Date.parse("12/31/#{strftime("%Y")}") << (12 - month)).day
  end

  def last_sunday
    d = self
    d -= 1 until d.wday == 0
    d
  end
end

class Hash
  def to_url
    map {|key, value| "#{CGI.escape key.to_s}=#{CGI.escape value.to_s}"}.join "&"
  end

  def to_cookie
    map {|key, value| "#{key}=#{value}"}.join('; ')
  end
end

class String
  def commify
    reverse.gsub(/(\d\d\d)(?=\d)/, '\1,').reverse
  end
end