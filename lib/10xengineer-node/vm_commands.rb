require '10xengineer-node/external'
require '10xengineer-node/vm'
require '10xengineer-node/dnsmasq'
require 'pathname'
require 'logger'
require 'net/ssh'
require 'yajl'
require 'uuid'
require 'lvm'

log = Logger.new(STDOUT)
log.level = Logger::WARN

# TODO refactor command support with shared logic and yield around different stages
# TODO prevent race conditions on API/broker side

command :prepare do |c|
  c.description = "Prepare new VM"

  c.option '--template TEMPLATE', String, 'VM template to use'
  c.option '--size SIZE', String, 'Logical volume size'
  c.option '--count COUNT', String, 'Number of VMs to create (default 1)'
  c.option '--sleep TIME', String, 'Sleep-time when creating multiple VMs (default to 0)'
  c.option '--vgname NAME', String, 'LVM Volume Group to use (lxc by default)'
  c.option '--pool NAME', String, '10xLab Pool name to use'

  c.action do |args, options|
    options.default :count => 1
    options.default :size => "1024MB"
    options.default :template => "ubuntu"
    options.default :sleep => 0
    options.default :pool => nil
    options.default :vgname => "lxc"

    # get list of templates
    templates = []

    lxc_templates = "/usr/lib/lxc/templates/lxc-*"
    Dir.glob(lxc_templates).each do |f|
      templates << Pathname.new(f).basename.to_s.delete("lxc-")
    end

    ext_abort "Template not recognized (#{options.template})" unless templates.include?(options.template)

    ext_abort "Volume group '#{options.vgname}' does not exists!" unless TenxEngineer::Node.volume_group(options.vgname)

    count = options.count.to_i

    uuid = UUID.new

    # TODO re-introduce multiple operations
    #count.times do 
    # prepare individual VMs
    id = uuid.generate

    puts "Generating VM '#{id}'" unless $json
    Syslog.log(Syslog::LOG_INFO, "generating vm=#{id}")

    cmd = "/usr/bin/sudo /usr/bin/lxc-create -f /etc/lxc/lxc.conf -t #{options.template} -n #{id} -B lvm --fssize #{options.size} --vgname #{options.vgname}"

    begin
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm = TenxEngineer::Node::VM.new(id, :prepared, options.pool, options.template, {:fs => {:size => options.size}})
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{id} created."
      end

      Syslog.log(Syslog::LOG_INFO, "vm=#{id} created")
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{id} failed reason='#{e.message}'")

      ext_abort e.message
    end

    # options sleep (default to 0 ~ no sleep)
    #sleep options.sleep.to_i
    #end
  end
end

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
    puts cmd

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

command :destroy do |c|
  c.option '--id ID', String, 'VM ID'
  c.action do |args, options|
    ext_abort "No VM ID" unless options.id

    begin
      vm = TenxEngineer::Node::VM.load(options.id)
    rescue Errno::ENOENT
      ext_abort "Invalid VM #{options.id}"
    end

    cmd = "/usr/bin/sudo /usr/bin/lxc-destroy -n #{options.id}"
    puts cmd

    begin
      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} destroy request")
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm.state = :destroyed
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{options.id} destroyed."
      end

      Syslog.log(Syslog::LOG_INFO, "vm=#{options.id} destroyed")
    rescue TenxEngineer::External::CommandFailure => e
      Syslog.log(Syslog::LOG_ERR, "vm=#{options.id} stop failed. reason=#{e.message}")
      ext_abort e.message
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

