require 'rubygems'
require 'pp'
require 'andand'
require 'cgi'
require 'yaml'

class Array
  def binary
    map {|e| yield(e) ? [e, nil] : [nil, e]}.transpose.map {|a| a.compact}
  end
end

class Object
  def to_cents
    (to_s.gsub(/[^-.0-9]/, '').to_f * 100).to_i
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

