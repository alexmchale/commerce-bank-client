#!/usr/bin/ruby

require 'rubygems'
require 'net/http'
require 'net/https'
require 'hpricot'
require 'pp'
require 'andand'
require 'cgi'
require 'yaml'
require 'ftools'

class Hash
  def to_url
    map {|key, value| "#{CGI.escape key.to_s}=#{CGI.escape value.to_s}"}.join "&"
  end

  def to_cookie
    map {|key, value| "#{key}=#{value}"}.join('; ')
  end
end

class MyCookies
  attr_reader :fields

  def initialize
    @fields = Hash.new
  end

  def append(response)
    CGI::Cookie.parse(response.header['set-cookie']).each do |key, value|
      @fields[key] = value.first
    end

    @fields.delete 'path'
    @fields.delete 'expires'

    self
  end

  def to_header
    { 'Cookie' => @fields.to_cookie }
  end
end

class WebClient
  attr_reader :fields, :cookies

  def initialize
    @cookies = MyCookies.new
    @http = Net::HTTP.new('banking.commercebank.com', 443)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def get(path, form = nil)
    @response = @http.get(path, @cookies.to_header)
    @cookies.append(@response)
    @fields = (form && get_form(@response.body, form)) || Hash.new
    @response
  end

  def post(path, form = nil)
    @response = @http.post(path, @fields.to_url, @cookies.to_header)
    @cookies.append(@response)
    @fields = (form && get_form(@response.body, form)) || Hash.new
    @response
  end

private

  def get_form(body, name)
    doc = Hpricot.parse(body)
    form = (doc/"##{name}").first
    fields = Hash[*((form/"input").map {|e| [ e.attributes['name'], e.attributes['value'] ]}.flatten)]
    fields['TestJavaScript'] = 'OK'
    fields
  end
end

def get_field(field)
  path = File.expand_path("~/.commerce.yaml")
  config = File.exists?(path) ? YAML.load(File.read path) : Hash.new

  unless config[field]
    print "Please enter the following:\n"
    print field, ": "

    config[field] = gets.to_s.chomp

    File.open(path, 'w') {|file| file.write(config.to_yaml)}
    File.chmod(0600, path)
  end

  config[field]
end

client = WebClient.new

client.get('/')
puts "Root get:"
pp client.fields

client.get('/CBI/login.aspx', 'MAINFORM')
puts "Login get:"
pp client.fields

client.fields['txtUserID'] = get_field('username')
response = client.post('/CBI/login.aspx', 'MAINFORM')

# If a question was asked, answer it then get the password page.
question = response.body.scan(/Your security question:&nbsp;&nbsp;(.*?)<\/td>/i).first.andand.first
if question
  puts "Pre-question:"
  pp client.fields

  client.fields['txtChallengeAnswer'] = get_field(question)
  client.fields['saveComputer'] = 'rdoBindDeviceNo'
  response = client.post('/CBI/login.aspx', 'MAINFORM')
end

puts "Last field:"
pp client.fields

if client.fields['__EVENTTARGET'] == 'btnLogin'
  client.fields['txtPassword'] = get_field('password')
  response = client.post('/CBI/login.aspx')
  response = client.get('/CBI/Accounts/CBI/Activity.aspx')
  puts response.body
else
  puts "Could not reach the password page."
  pp client.fields
  puts response.body
end
