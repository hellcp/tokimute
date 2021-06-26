CONFIG_FILE = 'config/config.yml'

class Config
  def self.value(key)
    if File.exist?(CONFIG_FILE)
      YAML.load_file(CONFIG_FILE)[key.to_s]
    else
      abort("Config file not found!")
    end
  end
end
