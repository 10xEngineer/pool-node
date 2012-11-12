require '10xengineer-node/external'
require '10xengineer-node/dnsmasq'
require '10xengineer-node/handlers'
require '10xengineer-node/zfs/snapshots'
require 'human_size_to_number'
require 'mixlib/shellout'
require 'securerandom'
require 'pathname'
require 'logger'
require 'net/ssh'
require 'yajl'
require 'uuid'

log = Logger.new(STDOUT)
log.level = Logger::WARN

command :create do |c|
  c.description = "Create new VM"

  # usage:
  # 
  # create --template ubuntu-precise64 --config base,ubuntu_uid --data hostname=demo1.local

  c.option '--template TEMPLATE', String, 'Source template'
  c.option '--rev VERSION', String, 'Source template version'
  c.option '--size SIZE', String, 'VM size'
  c.option '--hostname HOSTNAME', String, 'VM hostname'
  c.option '--handlers HANDLERS', String, "VM configuration handlers to use"
  c.option '--data DATA', String, "Custom VM data (k/v pairs)"
  c.option '--keys KEYS', String, "Setup authorized keys for --user specified"
  c.option '--defer', "Defer VM start"

  # TODO template to specify default handlers 
  # TODO global handlers, per-template handlers - ie basic is shared

  c.action do |args, options|
    options.default :template => "ubuntu-precise64"
    options.default :rev => "default"
    options.default :size => "512"
    options.default :handlers => "base,lab_uid,lab_setup"
    options.default :data => ""

    root_dir = "/var/lib"
    source_ds = "lxc/_templates/_default"
    template_dir = File.join(root_dir, source_ds, options.template)

    vm_ds = "lxc"

    # FIXME validate handlers first

    raise "Machine hostname is required" unless options.hostname

    # TODO should use zfs list -t snapshot
    raise "Template not recognized (#{options.template})" unless File.exists?(template_dir)

    # create VM
    uuid = UUID.new
    id = uuid.generate
    puts "Creating vm='#{id}'" unless $json

    t_start = Time.now

    begin
      # create new dataset
      TenxEngineer::External.execute("zfs clone -p #{source_ds}/#{options.template}@#{options.rev} #{vm_ds}/#{id}")

      t_clone = Time.now - t_start

      # 5 GB per each 256MB slice of memory
      # TODO configurable with fallback to 5 GB
      quota = (options.size.to_i / 256) * 5

      TenxEngineer::External.execute("zfs set quota=#{quota}G #{vm_ds}/#{id}")
      #TenxEngineer::External.execute("zfs snapshot #{vm_ds}/#{id}@initial")

      t_zfs = Time.now - t_start

      # basic (/etc/network/interfaces, /etc/hostname, /etc/hosts, /etc/resolv.conf, add user)
      vm_dir = File.join(root_dir, vm_ds, id)
      config = ConfigFactory.new(vm_dir)

      # configuration handlers
      _data = Hash[*options.data.split(/[,=]/)]
      data = _data.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

      # setup configuration defaults
      data[:hostname] = options.hostname

      rand = SecureRandom.hex.scan(/.{2}/m)[0..2].join(':')
      data[:hwaddr] = "00:16:3e:#{rand}"
      data[:keys] = options.keys

      # TODO load handlers from template & merge with options.handlers
      # TODO precedence?
      options.handlers.split(',').each do |handler|
        config.run(handler, data)
      end

      t_config = Time.now - t_start

      TenxEngineer::External.execute("/usr/bin/lxc-start -n #{id} -d") unless options.defer

      t_total = Time.now - t_start

      # TODO how to do cleanup - like lxb-ubuntu cleanup on failure

      options.defer ? result = "created" : result = "started"
      Syslog.log(Syslog::LOG_INFO, "vm=#{id} #{result} t_clone=#{t_clone} t_zfs=#{t_zfs} t_config=#{t_config} t_total=#{t_total}")

      if $json
        snapshots = Labs::Snapshots.for_machine(id)
        data = {
          :uuid => id,
          :state => result,
          :name => options.hostname,
          :snapshots => snapshots
        }

        puts Yajl::Encoder.encode(data)
      else
        puts "Machine '#{options.hostname} with UUID #{id} #{result}"
      end
    rescue TenxEngineer::External::CommandFailure => e
        ext_abort e.message
    end
  end
end

command :snapshot do |c|
  c.description = "Create new VM snapshot"

  c.option '--id ID', String, 'VM ID'
  c.option '--name NAME', String, 'Snapshot name'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    options.default :name => DateTime.now.strftime('%Y-%m-%d_%H-%M-%S_%L')

    vm_ds = "lxc"

    snapshot = Labs::Snapshots.details(options.id, options.name)
    
    ext_abort "Snapshot '#{options.name}' already exists!" if snapshot

    t_start = Time.now
    begin
      res = TenxEngineer::External.execute("zfs snapshot #{vm_ds}/#{options.id}@#{options.name}")

      t_total = Time.now - t_start
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} snapshot=#{options.name} t_total=#{t_total}")

      if $json
        snapshot = Labs::Snapshots.details(options.id, options.name)

        puts Yajl::Encoder.encode(snapshot)
      else
        puts "Snapshot '#{options.name}' created."
      end
    rescue TenxEngineer::External::CommandFailure => e
        ext_abort e.message
    end
  end
end

command :revert do |c|
  c.description = "Revert machine to specified snapshot"

  c.option '--id ID', String, 'VM ID'
  c.option '--name NAME', String, 'Snapshot name'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id
    ext_abort "Snapshot name required" unless options.name

    snapshot = Labs::Snapshots.details(options.id, options.name)
    ext_abort "Snapshot '#{options.name}' does not exists!" unless snapshot

    vm_ds = "lxc"

    t_start = Time.now
    begin
      res = TenxEngineer::External.execute("zfs rollback -r  #{vm_ds}/#{options.id}@#{options.name}")

      t_total = Time.now - t_start
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} snapshot=#{options.name} t_total=#{t_total} rollback")

      if $json
        puts Yajl::Encoder.encode({})
      else
        puts "Machine '#{options.id}' reverted to snapshot '#{options.name}'"
      end
    rescue TenxEngineer::External::CommandFailure => e
        ext_abort e.message
    end
  end
end

command :delshot do |c|
  c.description = "Remove existing VM snapshot"

  c.option '--id ID', String, 'VM ID'
  c.option '--name NAME', String, 'Snapshot name'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id
    ext_abort "Snapshot name required" unless options.name

    vm_ds = "lxc"

    snapshot = Labs::Snapshots.details(options.id, options.name)
    ext_abort "Snapshot '#{options.name}' does not exists!" unless snapshot

    t_start = Time.now
    begin
      res = TenxEngineer::External.execute("zfs destroy #{vm_ds}/#{options.id}@#{options.name}")

      t_total = Time.now - t_start
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} snapshot=#{options.name} t_total=#{t_total} destroyed")

      if $json
        puts Yajl::Encoder.encode({})
      else
        puts "Snapshot '#{options.name}' destroyed."
      end
    rescue TenxEngineer::External::CommandFailure => e
        ext_abort e.message
    end
  end
end

command :ps do |c|
  c.option '--id ID', String, 'Machine ID'
  c.action do |args, options|
    Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} request=ps")

    ext_abort "No Machine ID provided" unless options.id

    #ps_cmd = "lxc-ps -n #{options.id} -L -f weo user,pid,ppid,%cpu,%mem,nlwp,vsz,rss,tty,stat,start,time,command"
    ps_cmd = "lxc-ps -n #{options.id} -L -f weo user,pid,ppid,%cpu,%mem,nlwp,vsz,rss,tty,stat,start,time,command"

    begin
      res = TenxEngineer::External.execute("/usr/bin/sudo #{ps_cmd}")

      # columns/positions
      lines = res.split("\n")
      header = lines.shift
      columns = header.split(" ").map {|i| i.downcase}

      ps_data = []

      # parse output
      lines.each do |line|
        continue if line.empty?

        line_parts = line.split(" ")

        out_line = {}
        columns.each {|col| out_line[col] = (col == columns.last) ? line_parts.join(' ') : line_parts.shift}

        command = out_line["command"]
        env = {}

        # process command and environment - the `ps` output command is still somewhat hard to 
        # parse, especially with nested key/value pairs. he/she who does that deserve to burn
        # in hell anyway.
        cmd_parts = command.split(" ").reverse

        buffer = []
        while (part = cmd_parts.shift)
          buffer << part

          kv_reg_ex = /^(\w*)=(.*)$/
          if kv_reg_ex.match part
            m = kv_reg_ex.match(buffer.reverse.join(' '))

            env[m.captures.first] = m.captures.last

            buffer = []
          end
        end

        out_line["command"] = buffer.reverse.join(' ')
        out_line["env"] = env

        ps_data << out_line
      end

      puts Yajl::Encoder.encode(ps_data)
    end

  end
end

command :destroy do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} destroy request")

      TenxEngineer::External.execute("/usr/bin/sudo /usr/bin/lxc-stop -n #{options.id}")

      vm_ds = "lxc"
      TenxEngineer::External.execute("zfs destroy -r #{vm_ds}/#{options.id}")

      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} destroyed")

      if $json
        puts Yajl::Encoder.encode({:uuid => options.id})
      end
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{options.id} stop failed. reason=#{e.message}")
      ext_abort e.message
    end
  end
end

command :list do |c|
  c.action do |args, options|
    res = TenxEngineer::External.execute("/usr/bin/sudo /sbin/zfs list -H -t all")

    machines = []

    entries = res.split("\n")
    entries.each do |entry|
      zfs_entry = entry.split(" ")

      name_ex = zfs_entry[0].match /^lxc\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/
      if name_ex
        machine_id = name_ex.captures.first

        used_size = (zfs_entry[3] << "B").human_size_to_number
        real_size = (zfs_entry[1] << "B").human_size_to_number
        total_size = (zfs_entry[2] << "B").human_size_to_number

        machine = {
          :uuid => machine_id,
          :used_size => used_size,
          :real_size => real_size,
          :total_size => total_size
        }

        machines << machine

        unless $json
          puts "#{machine_id}\t#{zfs_entry[3]}\t#{zfs_entry[1]}\t#{zfs_entry[2]}"
        end
      end
    end

    if $json
        puts Yajl::Encoder.encode(machines)
    end

  end
end
