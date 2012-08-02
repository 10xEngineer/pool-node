require 'yajl'
require 'yaml'

def ext_abort(reason, json = $json)
  puts (json ? Yajl::Encoder.encode({:reason => reason}) : reason)
  
  Process.exit 1
end

def config_endpoint(config = "/etc/10xeng.yaml")
  return nil unless File.exists?(config)

  config = YAML::load(File.open(config))

  return config["hostnode"]["endpoint"] || nil
end
