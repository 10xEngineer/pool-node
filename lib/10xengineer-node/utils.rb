require 'yajl'

def ext_abort(reason, json = $json)
  puts (json ? Yajl::Encoder.encode({:reason => reason}) : reason)
  
  Process.exit 1
end

def config_endpoint(config = "/etc/10xlabs-hostnode.json")
  return nil unless File.exists?(config)

  config = Yajl::Parser.parse(File.open(config))

  return config["endpoint"] || nil
end
