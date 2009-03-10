require 'rubygems'
require 'pp'
require 'andand'
require 'cgi'
require 'yaml'
require 'RMagick'

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

module Magick
  class Image
    def autocrop(red = 65535, green = 65535, blue = 65535)
      low_x = 0
      low_y = 0
      high_x = columns
      high_y = rows

      croppable = Proc.new do |x, y|
        pixel = pixel_color(x, y)
        (pixel.red == red) && (pixel.green == green) && (pixel.blue == blue)
      end

      # Scan the top horizontal.
      low_y += 1 until (low_y == rows) || (low_x..high_x).find {|x| !croppable.call(x, low_y)}

      # Scan the bottom horizontal.
      high_y -= 1 until (low_y == high_y) || (low_x..high_x).find {|x| !croppable.call(x, high_y)}

      # Scan the left vertical.
      low_x += 1 until (low_x == columns) || (low_y..high_y).find {|y| !croppable.call(low_x, y)}

      # Scan the right vertical.
      high_x -= 1 until (low_x == high_x) || (low_y..high_y).find {|y| !croppable.call(high_x, y)}

      width = high_x - low_x
      height = high_y - low_y

      crop low_x, low_y, width, height
    end
  end
end
