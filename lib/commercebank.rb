require 'rubygems'
require 'net/http'
require 'net/https'
require 'hpricot'
require 'andand'
require 'cgi'
require 'yaml'
require 'ftools'
require 'time'
require 'date'
require 'json'
require 'htmlentities'
require 'gmail'
require 'appconfig'
require 'commercebank/monkey.rb'

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
  attr_reader :register, :current, :available

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
    (@current, @available) = parse_balance(response.body)
    @pending = parse_pending(response.body)

    client.fields['Anthem_UpdatePage'] = 'true'
    client.fields['txtFilterFromDate:textBox'] = Time.parse('1/1/2000').strftime('%m/%d/%Y')
    client.fields['txtFilterToDate:textBox'] = Time.now.strftime('%m/%d/%Y')
    response = client.post('/CBI/Accounts/CBI/Activity.aspx?Anthem_CallBack=true')

    raw_data = JSON.parse(response.body)
    @register = parse_register(raw_data['controls']['pnlPosted'])
  end

  def daily_summary
    today, yesterday, this_week, last_week = [], [], [], []

    register.each do |entry|
      if    entry[:date] == Date.today                               then today << entry
      elsif entry[:date] == (Date.today - 1)                         then yesterday << entry
      elsif entry[:date] >= Date.today.last_sunday                   then this_week << entry
      elsif entry[:date] >= (Date.today.last_sunday - 1).last_sunday then last_week << entry
      end
    end

    yield 'Pending', @pending
    yield 'Today', today
    yield 'Yesterday', yesterday
    yield 'This Week', this_week
    yield 'Last Week', last_week
  end

  def monthly_summary(day_in_month = (Date.today - Date.today.day))
    first_of_month = day_in_month - day_in_month.day + 1
    last_of_month = first_of_month + day_in_month.days_in_month - 1

    entries = register.find_all {|entry| entry[:date] >= first_of_month && entry[:date] <= last_of_month}

    yield day_in_month.strftime('%B'), entries
  end

private

  def parse_balance(body)
    Hpricot.buffer_size = 262144
    doc = Hpricot.parse(body)
    summaryRows = doc/"table.summaryTable"/"tr"
    current = (summaryRows[3]/"td")[1].inner_html.to_cents
    available = (summaryRows[4]/"td")[1].inner_html.to_cents
    [current, available]
  end

  def parse_pending(body)
    Hpricot.buffer_size = 262144
    doc = Hpricot.parse(body)
    coder = HTMLEntities.new

    (doc/"#grdMemoPosted"/"tr").map do |e|
      next nil unless (e['class'] == 'item' || e['class'] == 'alternatingItem')

      values = (e/"td").map {|e1| coder.decode(e1.inner_html.strip)}

      debit = values[2].to_cents
      credit = values[3].to_cents
      delta = credit - debit

      { :date => Date.parse(values[0]),
        :destination => values[1],
        :delta => delta,
        :debit => debit,
        :credit => credit }
    end.compact
  end

  def parse_register(body)
    Hpricot.buffer_size = 262144
    doc = Hpricot.parse(body)
    coder = HTMLEntities.new
    (doc/"#grdHistory"/"tr").map do |e|
      next nil unless [ 'item', 'alternatingitem' ].include? e['class'].to_s.downcase

      anchor = e.at("a")
      values = (e/"td").map {|e1| e1.inner_html}
      date = Date.parse(values[0])
      check = values[1].strip
      debit = values[3].to_cents
      credit = values[4].to_cents
      delta = credit - debit
      total = values[5].scan(/\$[\d,]+\.\d\d/).first.to_cents

      images = (e/"a").find_all do |e1|
        e1['target'].to_s.downcase == 'checkimage'
      end.map do |e1|
        { :url => e1['href'], :title => e1.inner_html.strip }
      end

      {
        :destination => coder.decode(anchor.inner_html.strip),
        :url => anchor['href'],
        :date => date,
        :check => check,
        :images => images,
        :delta => delta,
        :debit => debit,
        :credit => credit,
        :total => total
      }
    end.compact
  end
end

