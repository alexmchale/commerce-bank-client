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
require 'htmlentities'

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

class WebClient
  attr_reader :fields, :cookies

  def initialize
    @cookies = Hash.new
    @http = Net::HTTP.new('banking.commercebank.com', 443)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def get(path, form = nil)
    response = @http.get(path, header)
    add_cookies(response)
    @fields = (form && get_form(response.body, form)) || Hash.new
    response
  end

  def post(path, form = nil)
    response = @http.post(path, @fields.to_url, header)
    add_cookies(response)
    @fields = (form && get_form(response.body, form)) || Hash.new
    response
  end

private

  def header
    { 'Cookie' => @cookies.to_cookie }
  end

  def get_form(body, name)
    Hpricot.buffer_size = 262144
    doc = Hpricot.parse(body)
    form = (doc/"##{name}").first
    fields = Hash[*((form/"input").map {|e| [ e.attributes['name'], e.attributes['value'] ]}.flatten)]
    fields['TestJavaScript'] = 'OK'
    fields
  end

  def add_cookies(response)
    CGI::Cookie.parse(response.header['set-cookie']).each do |key, value|
      @cookies[key] = value.first
    end

    @cookies.delete 'path'
    @cookies.delete 'expires'

    self
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

class CommerceBank
  attr_reader :register

  def initialize
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

    raise "could not reach the password page" unless client.fields['__EVENTTARGET'] == 'btnLogin'

    client.fields['txtPassword'] = get_field('password')
    response = client.post('/CBI/login.aspx')

    response = client.get('/CBI/Accounts/CBI/Activity.aspx', 'MAINFORM')

    client.fields['Anthem_UpdatePage'] = 'true'
    client.fields['txtFilterFromDate:textBox'] = Time.parse('1/1/2000').strftime('%m/%d/%Y')
    client.fields['txtFilterToDate:textBox'] = Time.now.strftime('%m/%d/%Y')
    response = client.post('/CBI/Accounts/CBI/Activity.aspx?Anthem_CallBack=true')

    raw_data = JSON.parse(response.body)
    @register = parse_register(raw_data['controls']['pnlPosted'])
  end

  def summary
    today, yesterday, this_week, last_week = [], [], [], []

    register.each do |entry|
      if    entry[:date] == Date.today                               then today << entry
      elsif entry[:date] == (Date.today - 1)                         then yesterday << entry
      elsif entry[:date] >= Date.today.last_sunday                   then this_week << entry
      elsif entry[:date] >= (Date.today.last_sunday - 1).last_sunday then last_week << entry
      end
    end

    [ summarize('Today', today), 
      summarize('Yesterday', yesterday),
      summarize('This Week', this_week),
      summarize('Last Week', last_week) ].compact.join("\n")
  end

private

  def summarize(label, entries)
    return nil if entries.length == 0

    text = label.to_s + ":\n"

    text + entries.map do |e| 
      delta = "%s%0.2f" % [ (e[:delta] >= 0 ? '+' : '-'), e[:delta].abs/100.0 ] 
      "%-100s %10s %10.2f\n" % [ e[:destination], delta, e[:total]/100.0 ]
    end.join
  end

  def parse_register(body)
    Hpricot.buffer_size = 262144
    doc = Hpricot.parse(body)
    coder = HTMLEntities.new
    (doc/"#grdHistory"/"tr").map do |e|
      next nil unless (e['class'] == 'item' || e['class'] == 'alternatingItem')

      anchor = e.at("a")
      values = (e/"td").map {|e1| e1.inner_html}
      debit = values[3].to_cents
      credit = values[4].to_cents
      delta = credit - debit
      total = values[5].to_cents

      { :destination => coder.decode(anchor.inner_html.strip),
        :url => anchor['href'],
        :date => Date.parse(values[0]),
        :delta => delta,
        :debit => debit,
        :credit => credit,
        :total => total }
    end.compact
  end
end

puts CommerceBank.new.summary
