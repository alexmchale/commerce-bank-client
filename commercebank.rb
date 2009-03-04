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
require 'monkey.rb'
require 'appconfig.rb'

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

class CommerceBank
  attr_reader :register

  def initialize
    @config = AppConfig.new('~/.commerce.yaml')

    client = WebClient.new

    client.get('/')

    client.get('/CBI/login.aspx', 'MAINFORM')

    client.fields['txtUserID'] = @config[:username]
    response = client.post('/CBI/login.aspx', 'MAINFORM')

    # If a question was asked, answer it then get the password page.
    question = response.body.scan(/Your security question:&nbsp;&nbsp;(.*?)<\/td>/i).first.andand.first
    if question
      client.fields['txtChallengeAnswer'] = @config[question]
      client.fields['saveComputer'] = 'rdoBindDeviceNo'
      response = client.post('/CBI/login.aspx', 'MAINFORM')
    end

    raise "could not reach the password page" unless client.fields['__EVENTTARGET'] == 'btnLogin'

    client.fields['txtPassword'] = @config[:password]
    response = client.post('/CBI/login.aspx')

    response = client.get('/CBI/Accounts/CBI/Activity.aspx', 'MAINFORM')

    client.fields['Anthem_UpdatePage'] = 'true'
    client.fields['txtFilterFromDate:textBox'] = Time.parse('1/1/2000').strftime('%m/%d/%Y')
    client.fields['txtFilterToDate:textBox'] = Time.now.strftime('%m/%d/%Y')
    response = client.post('/CBI/Accounts/CBI/Activity.aspx?Anthem_CallBack=true')

    raw_data = JSON.parse(response.body)
    @register = parse_register(raw_data['controls']['pnlPosted'])
  end

  def weekly_summary
    today, yesterday, this_week, last_week = [], [], [], []

    register.each do |entry|
      if    entry[:date] == Date.today                               then today << entry
      elsif entry[:date] == (Date.today - 1)                         then yesterday << entry
      elsif entry[:date] >= Date.today.last_sunday                   then this_week << entry
      elsif entry[:date] >= (Date.today.last_sunday - 1).last_sunday then last_week << entry
      end
    end

    summarize('Today' => today, 
              'Yesterday' => yesterday, 
              'This Week' => this_week, 
              'Last Week' => last_week, 
              :order => [ 'Today', 'Yesterday', 'This Week', 'Last Week' ])
  end

  def monthly_summary(day_in_month = (Date.today - Date.today.day))
    first_of_month = day_in_month - day_in_month.day + 1
    last_of_month = first_of_month + day_in_month.days_in_month - 1
    entries = register.find_all {|entry| entry[:date] >= first_of_month && entry[:date] <= last_of_month}
    summarize_html(day_in_month.strftime('%B') => entries)
  end

private

  def summarize(entries)
    (entries[:order] || entries.keys).map do |label|
      next if entries[label].length == 0

      label.to_s + ":\n" + entries[label].map do |e| 
        delta = "%s%0.2f" % [ (e[:delta] >= 0 ? '+' : '-'), e[:delta].abs/100.0 ] 
        "%s %-100s %10s %10.2f\n" % [ e[:date].strftime('%02m/%02d/%04Y'), e[:destination], delta, e[:total]/100.0 ]
      end.join
    end.compact.join("\n")
  end

  def summarize_html(entries)
    html = ''

    (entries[:order] || entries.keys).each do |label|
      next if entries[label].length == 0

      html += '<h2>' + label + '</h2>'

      html += '<table>'

      html += '<tr>'
      html += '<th>Date</th>'
      html += '<th>Destination</th>'
      html += '<th>Amount</th>'
      html += '<th>Total</th>'
      html += '</tr>'

      entries[label].each do |e| 
        delta = "%s%0.2f" % [ (e[:delta] >= 0 ? '+' : '-'), e[:delta].abs/100.0 ] 
        total = "%0.2f" % (e[:total]/100.0)

        html += '<tr>'
        html += '<th>' + e[:date].strftime('%02m/%02d/%04Y') + '</th>'
        html += '<th>' + e[:destination] + '</th>'
        html += '<th>' + delta + '</th>'
        html += '<th>' + total + '</th>'
        html += '</tr>'
      end

      html += '</table>'
    end

    html
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

cb = CommerceBank.new

puts "WEEKLY SUMMARY"
puts cb.weekly_summary

puts

puts "MONTHLY SUMMARY"
puts cb.monthly_summary
