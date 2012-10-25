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

def run_as(user, &block)
  u = (user.is_a? Integer) ? Etc.getpwuid(user) : Etc.getpwnam(user)

  io_read, io_write = IO.pipe

  pid = Process.fork do
    io_read.close 

    Process::Sys.setgid(u.gid)
    Process::Sys.setuid(u.uid)

    result = block.call(user)

    Marshal.dump(result, io_write)
  end

  io_write.close
  result = io_read.read

  Process.wait(pid)

  Marshal.load(result)
end