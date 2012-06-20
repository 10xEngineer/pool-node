require 'yajl'
require 'yaml'

def ext_abort(reason, json = $json)
  abort (json ? Yajl::Encoder.encode({:reason => reason}) : reason)
end

def config_endpoint(config = "/etc/10xeng.yaml")
  return nil unless File.exists?(config)

  config = YAML::load(File.open(config))

  return config["hostnode"]["endpoint"] || nil
end
