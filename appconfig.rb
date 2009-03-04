require 'rubygems'
require 'pp'
require 'andand'
require 'yaml'

class AppConfig
  def initialize(path)
    @path = path
  end

  def [](field)
    field = field.to_s
    path = File.expand_path(@path)
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
end
