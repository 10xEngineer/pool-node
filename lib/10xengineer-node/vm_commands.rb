require '10xengineer-node/external'
require '10xengineer-node/vm'
require '10xengineer-node/dnsmasq'
require '10xengineer-node/handlers'
require 'mixlib/shellout'
require 'securerandom'
require 'pathname'
require 'logger'
require 'net/ssh'
require 'yajl'
require 'uuid'
require 'lvm'

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
  c.option '--defer', "Defer VM start"

  # TODO template to specify default handlers 
  # TODO global handlers, per-template handlers - ie basic is shared

  c.action do |args, options|
    options.default :template => "ubuntu-precise64"
    options.default :rev => "default"
    options.default :size => "256"
    options.default :hostname => "sizzling-cod"
    options.default :handlers => "base,u_ubuntu,lab_setup"
    options.default :data => ""

    uuid = UUID.new
    id = uuid.generate
    puts "Creating vm='#{id}'" unless $json

    root_dir = "/var/lib"
    source_ds = "lxc/_templates/_default"
    template_dir = File.join(root_dir, source_ds, options.template)

    vm_ds = "lxc"

    # FIXME validate handlers first

    # TODO should use zfs list -t snapshot
    raise "Template not recognized (#{options.template})" unless File.exists?(template_dir)

    t_start = Time.now

    begin
      # create new dataset
      TenxEngineer::External.execute("zfs clone -p #{source_ds}/#{options.template}@#{options.rev} #{vm_ds}/#{id}")

      t_clone = Time.now - t_start

      # 5 GB per each 256MB slice of memory
      # TODO configurable with fallback to 5 GB
      quota = (options.size.to_i / 256) * 5

      TenxEngineer::External.execute("zfs set quota=#{quota}G #{vm_ds}/#{id}")
      TenxEngineer::External.execute("zfs snapshot #{vm_ds}/#{id}@initial")

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

      # TODO load handlers from template & merge with options.handlers
      # TODO precedence?
      options.handlers.split(',').each do |handler|
        config.run(handler, data)
      end

      t_config = Time.now - t_start

      TenxEngineer::External.execute("/usr/bin/lxc-start -n #{id} -d") unless options.defer

      t_total = Time.now - t_start

      # TODO how to do cleanup - like lxb-ubuntu cleanup on failure

      options.defer ? result = "created" : result = "created"
      Syslog.log(Syslog::LOG_INFO, "vm=#{id} #{result} t_clone=#{t_clone} t_zfs=#{t_zfs} t_config=#{t_config} t_total=#{t_total}")
    rescue TenxEngineer::External::CommandFailure => e
        ext_abort e.message
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
      TenxEngineer::External.execute("/usr/bin/sudo /usr/bin/lxc-destroy -n #{options.id}")

      vm_ds = "lxc"
      TenxEngineer::External.execute("zfs destroy -r #{vm_ds}/#{options.id}")

      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} destroyed")
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{options.id} stop failed. reason=#{e.message}")
      ext_abort e.message
    end
  end
end

# ---- 

command :allocate do |c|
  c.description = "Allocate prepared VM"

  # TODO how to prepare VM? (--prepare?); need to pass aditional options
  c.option '--id ID', String, 'Prepared VM id'
  c.option '--profile PROFILE', String, 'Profile to use'

  c.action do |args, options|
    options.profile = nil

    # validate container
    # TODO refactor
    # TODO x1 - check file
    vm_desc = File.new("#{TenxEngineer::Node::ROOT}/data_bags/vms/#{options.id}.json", "r")
    vm = TenxEngineer::Node::VM.from_json(vm_desc)

    # TODO shared function to validate VM

    ext_abort "Specified VM not '#{options.id}' not available (currently in state #{vm.state})." unless vm.state == :prepared

    # change local status (if abandoned, it's node responsibibility to clean it up)
    vm.state = :allocated
    vm.save!

    # TODO run profile provisioning
    # lxc-execute 

    if $json
      puts vm.to_json
    else
      puts "VM #{options.id} allocated."
    end
  end
end

command :start do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      vm = TenxEngineer::Node::VM.load(options.id)
    rescue Errno::ENOENT
      ext_abort "Invalid VM #{options.id}"
    end

    cmd = "/usr/bin/sudo /usr/bin/lxc-start -n #{options.id} -d"

    begin
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} starting")

      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm.state = :running
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{options.id} started."
      end

      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} started")
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{options.id} startup failed. reason=#{e.message}")
      ext_abort e.message
    end
  end
end

command :stop do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      vm = TenxEngineer::Node::VM.load(options.id)
    rescue Errno::ENOENT
      ext_abort "Invalid VM #{options.id}"
    end

    cmd = "/usr/bin/sudo /usr/bin/lxc-shutdown -n #{options.id}"

    begin
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} stop request")
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm.state = :allocated
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{options.id} stopped."
      end

      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} stopped")
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{options.id} stop failed. reason=#{e.message}")
      ext_abort e.message
    end
  end
end

command :list do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    vms = []

    # find 
    vm_files = File.join(TenxEngineer::Node::VM.vm_storage, "*.json")
    Dir.glob(vm_files).each do |f|
      vm_id = File.basename(f, '.*')

      vm = TenxEngineer::Node::VM.load(vm_id)

      vms << {
        :id => vm_id,
        :state => vm.state,
        :type => vm.type,
        :ip_addr => vm.ip_addr
      }
    end

    if $json
      puts Yajl::Encoder.encode(vms)
    else
      vms.each do |vm|
        printf "%s\t%s\t%s", vm[:id], vm[:state], vm[:type]
        printf "\t%s", vm.ip_addr if vm[:ip_addr]
        puts
      end

    end
  end
end




command :hibernate do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      vm = TenxEngineer::Node::VM.load(options.id)
    rescue Errno::ENOENT
      ext_abort "Invalid VM #{options.id}"
    end

    cmd = "/usr/bin/sudo /usr/bin/lxc-freeze -n #{options.id}"
    puts cmd

    begin
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm.state = :hibernated
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{options.id} hibernated."
      end
    rescue TenxEngineer::External::CommandFailure => e
      ext_abort e.message
    end
  end
end

command :restore do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      vm = TenxEngineer::Node::VM.load(options.id)
    rescue Errno::ENOENT
      ext_abort "Invalid VM #{options.id}"
    end

    cmd = "/usr/bin/sudo /usr/bin/lxc-unfreeze -n #{options.id}"
    puts cmd

    begin
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm.state = :running
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{options.id} hibernated."
      end
    rescue TenxEngineer::External::CommandFailure => e
      ext_abort e.message
    end
  end
end

# TODO verify vms
# build set from a) data bag VMs c) lxc-list
# compare to find orphans 
# verify the state of invidual VMs / report to API
# TODO system wide microcloud API configuration

command :info do |c|
  # TODO print LXC information

  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    abort "missing VM ID (use --id option)" unless options.id

    vm = TenxEngineer::Node::VM.load(options.id)

    if $json
      puts vm.to_json
    else
      puts vm
    end
  end
end

