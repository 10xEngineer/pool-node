require '10xengineer-node/external'
require '10xengineer-node/vm'
require 'pathname'
require 'logger'
require 'net/ssh'
require 'uuid'
require 'lvm'

log = Logger.new(STDOUT)
log.level = Logger::WARN

command :prepare do |c|
  c.description = "Prepare new VM"

  c.option '--template TEMPLATE', String, 'VM template to use'
  c.option '--size SIZE', String, 'Logical volume size'
  c.option '--count COUNT', String, 'Number of VMs to create (default 1)'
  c.option '--sleep TIME', String, 'Sleep-time when creating multiple VMs (default to 0)'
  c.option '--vgname NAME', String, 'LVM Volume Group to use (lxc by default)'

  c.action do |args, options|
    options.default :count => 1
    options.default :size => "512MB"
    options.default :template => "ubuntu"
    options.default :sleep => 0
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

    cmd = "/usr/bin/sudo /usr/bin/lxc-create -f /etc/lxc/lxc.conf -t #{options.template} -n v-#{id} -B lvm --fssize #{options.size} --vgname #{options.vgname}"

    begin
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm = TenxEngineer::Node::VM.new(id, :prepared, nil, options.template, {:fs => {:size => options.size}})
      vm.save!

      if $json
        puts vm.to_json
      else
        puts "VM #{id} created."
      end
    rescue TenxEngineer::External::CommandFailure => e
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
    vm_desc = File.new("#{TenxEngineer::Node::ROOT}/data_bags/vms/#{id}.json", "r")
    vm = TenxEngineer::Node::VM.from_json(vm_desc)

    # TODO shared function to validate VM

    ext_abort "Specified VM not '#{id}' not available (#{vm.state})." unless vm.state == :prepared

    # change local status (if abandoned, it's node responsibibility to clean it up)
    vm.state = :allocated
    vm.save!

    # TODO run profile provisioning

    if $json
      puts vm.to_json
    else
      puts "VM #{id} allocated."
    end
  end
end

