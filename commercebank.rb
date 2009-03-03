require 'rubygems'
require 'net/http'
require 'net/https'
require 'hpricot'
require 'pp'
require 'andand'
require 'cgi'
require 'yaml'
require 'ftools'
require 'time'
require 'date'
require 'json'

class Object
  def to_cents
    (to_s.gsub(/[^-.0-9]/, '').to_f * 100).to_i
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

def parse_register(body)
  doc = Hpricot.parse(body)
  (doc/"#grdHistory"/"tr").map do |e|
    next nil unless (e['class'] == 'item' || e['class'] == 'alternatingItem')

    anchor = e.at("a")
    values = (e/"td").map {|e1| e1.inner_html}
    debit = values[3].to_cents
    credit = values[4].to_cents
    delta = credit - debit
    total = values[5].to_cents

    { :destination => anchor.inner_html.strip,
      :url => anchor['href'],
      :date => Date.parse(values[0]),
      :delta => delta,
      :debit => debit,
      :credit => credit,
      :total => total }
  end.compact
end

Hpricot.buffer_size = 262144

client = WebClient.new

client.get('/')

client.get('/CBI/login.aspx', 'MAINFORM')

client.fields['txtUserID'] = get_field('username')
response = client.post('/CBI/login.aspx', 'MAINFORM')

# If a question was asked, answer it then get the password page.
question = response.body.scan(/Your security question:&nbsp;&nbsp;(.*?)<\/td>/i).first.andand.first
if question
  client.fields['txtChallengeAnswer'] = get_field(question)
  client.fields['saveComputer'] = 'rdoBindDeviceNo'
  response = client.post('/CBI/login.aspx', 'MAINFORM')
end

if client.fields['__EVENTTARGET'] == 'btnLogin'
  client.fields['txtPassword'] = get_field('password')
  response = client.post('/CBI/login.aspx')
  response = client.get('/CBI/Accounts/CBI/Activity.aspx', 'MAINFORM')
else
  puts "Could not reach the password page."
  pp client.fields
  puts response.body
  exit
end

client.fields['Anthem_UpdatePage'] = 'true'
client.fields['txtFilterFromDate:textBox'] = Time.parse('1/1/2000').strftime('%m/%d/%Y')
client.fields['txtFilterToDate:textBox'] = Time.now.strftime('%m/%d/%Y')
response = client.post('/CBI/Accounts/CBI/Activity.aspx?Anthem_CallBack=true')

raw_data = JSON.parse(response.body)
register = parse_register(raw_data['controls']['pnlPosted'])
pp register

