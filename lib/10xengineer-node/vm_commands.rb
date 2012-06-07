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

    abort "Template not recognized (#{options.template})" unless templates.include?(options.template)

    abort "Volume group '#{options.vgname}' does not exists!" unless TenxEngineer::Node.volume_group(options.vgname)

    count = options.count.to_i

    uuid = UUID.new
    count.times do 
      # prepare individual VMs
      id = uuid.generate

      puts "Generating VM '#{id}'"

      cmd = "/usr/bin/sudo /usr/bin/lxc-create -t #{options.template} -n v-#{id} -B lvm --fssize #{options.size} --vgname #{options.vgname}"
      TenxEngineer::External.execute(cmd) do |l|
        # TODO log to hostnode stream
      end

      vm = TenxEngineer::Node::VM.new(id, :prepared, nil, options.template, {:fs => {:size => options.size}})

      open("#{TenxEngineer::Node::ROOT}/data_bags/vms/#{id}.json", "w") { |f| f << vm.to_json }

      # TODO data bag location / default per machine ~/mchammer/data_bags?
      # TODO save as data bag item

      # options sleep (default to 0 ~ no sleep)
      sleep options.sleep.to_i
    end

  end
end
