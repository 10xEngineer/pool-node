config_t = File.join(File.dirname(__FILE__), '../templates/config.erb')
erb = Erubis::Eruby.new(File.read(config_t))

config_f = File.join(@vm_dir, "config")
File.open(config_f, 'w') {|f| f.write(erb.result(binding()))}