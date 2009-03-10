require 'openssl'
require 'net/smtp'
require 'base64'

class GMail
  def initialize(username, password)
    @username = username
    @password = password
  end

  def start(to, subject, body, body_type = 'text/plain')
    @to = to.to_s
    @subject = subject.to_s
    @body = body.to_s
    @body_type = body_type
    @attachments = []

    self
  end

  def add_data(name, data, type)
    @attachments << { :name => name, :data => data, :type => type }

    self
  end

  def add_file(filename, content_type)
    add_data File.basename(File.expand_path(filename)), File.read(filename), content_type
  end

  def add_jpeg(filename, data = nil)
    name = File.basename filename
    data ||= File.read(filename)
    type = 'image/jpeg'

    add_data name, data, type
  end

  def compose
    boundary = rand(2**128).to_s(16)

    if @attachments.length > 0
      attachments = @attachments.map do |attachment|
        "--#{boundary}\r\n" +
        "Content-Type: #{attachment[:type]}; name=\"#{attachment[:name]}\"\r\n" +
        "Content-Disposition: attachment; filename=\"#{attachment[:name]}\"\r\n" +
        "Content-Transfer-Encoding: base64\r\n" +
        "\r\n" +
        Base64.encode64(attachment[:data])
      end.compact.join

      "Date: #{Time.now.to_s}\r\n" +
      "From: #{@username}\r\n" +
      "To: #{@to}\r\n" +
      "Subject: #{@subject}\r\n" +
      "MIME-Version: 1.0\r\n" +
      "Content-Type: multipart/mixed; boundary=\"#{boundary}\"\r\n" +
      "\r\n" +
      "--#{boundary}\r\n" +
      "Content-Type: text/plain\r\n" +
      "\r\n" +
      "#{@body}\r\n" +
      "\r\n" +
      attachments +
      "--#{boundary}--\r\n" +
      "\r\n.\r\n"
    else
      "Date: #{Time.now.to_s}\r\n" +
      "From: #{@username}\r\n" +
      "To: #{@to}\r\n" +
      "Subject: #{@subject}\r\n" +
      "Content-Type: text/plain\r\n" +
      "\r\n" +
      "#{@body}\r\n" +
      "\r\n.\r\n"
    end
  end

  def dispatch
    Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', @username, @password, :plain) do |smtp|
      smtp.send_message compose, @username, @to
    end
  end

  def send(to, subject, body, content_type = 'text/plan')
    Net::SMTP.start('smtp.gmail.com', 587, 'gmail.com', @username, @password, :plain) do |smtp|
      msg = "From: #{@username}\r\nTo: #{to}\r\nSubject: #{subject}\r\nContent-Type: #{content_type}\r\n\r\n#{body}"
      smtp.send_message msg, @username, to
    end
  end
end

# Net::SMTP monkeypatching was taken from:
# http://www.stephenchu.com/2006/06/how-to-use-gmail-smtp-server-to-send.html
Net::SMTP.class_eval do
  private
  def do_start(helodomain, user, secret, authtype)
    raise IOError, 'SMTP session already started' if @started
    check_auth_args(user, secret) if (user or secret)

    sock = timeout(@open_timeout) { TCPSocket.open(@address, @port) }
    @socket = Net::InternetMessageIO.new(sock)
    @socket.read_timeout = 60 #@read_timeout
    @socket.debug_output = STDERR #@debug_output

    check_response(critical { recv_response() })
    do_helo(helodomain)

    raise 'openssl library not installed' unless defined?(OpenSSL)
    starttls
    ssl = OpenSSL::SSL::SSLSocket.new(sock)
    ssl.sync_close = true
    ssl.connect
    @socket = Net::InternetMessageIO.new(ssl)
    @socket.read_timeout = 60 #@read_timeout
    @socket.debug_output = STDERR #@debug_output
    do_helo(helodomain)

    authenticate user, secret, authtype if user
    @started = true
  ensure
    unless @started
      # authentication failed, cancel connection.
        @socket.close if not @started and @socket and not @socket.closed?
      @socket = nil
    end
  end

  def do_helo(helodomain)
     begin
      if @esmtp
        ehlo helodomain
      else
        helo helodomain
      end
    rescue Net::ProtocolError
      if @esmtp
        @esmtp = false
        @error_occured = false
        retry
      end
      raise
    end
  end

  def starttls
    getok('STARTTLS')
  end

  def quit
    begin
      getok('QUIT')
    rescue EOFError
    end
  end
end
