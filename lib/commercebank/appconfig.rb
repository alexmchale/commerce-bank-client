require 'yaml'

class AppConfig
  def initialize(path)
    @path = path
  end

  def []=(field, value)
    field = field.to_s
    config = read
    config[field] = value
    config.delete(field) unless value
    save(config)
    value
  end

  def [](field)
    field = field.to_s
    read[field]
  end

  def get(field)
    value = self[field]

    unless value   
      print "Please enter the following:\n"
      print field, ": "

      value = self[field] = gets.to_s.chomp
    end

    value
  end

private
  
  def read
    path = File.expand_path(@path)
    File.exists?(path) ? YAML.load(File.read path) : Hash.new
  end

  def save(config)
    path = File.expand_path(@path)
    File.open(path, 'w') {|file| file.write(config.to_yaml)}
    File.chmod(0600, path)
  end
end
