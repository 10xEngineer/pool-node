require '10xengineer-node/vm'

# TODO simulate :old 

[:add, :del, :old].each do |cmd_name|
  command cmd_name do |c|
    c.action do |args, options|

      # additional parameters
      mac_addr = args.shift
      ip_addr = args.shift
      vm_id = args.shift

      vm = TenxEngineer::Node::VM.load(vm_id)

      if cmd_name == :add
        vm.descriptor[:ip_addr] = ip_addr
        vm.descriptor[:mac_addr] = mac_addr
      else
        vm.descriptor[:ip_addr] = nil
        vm.descriptor[:mac_addr] = nil
      end

      vm.save!

      actions = {
        :add => :start,
        :del => :stop
      }

      Syslog.log(Syslog::LOG_INFO, "action=#{cmd_name} mac_addr=#{mac_addr} ip_addr=#{ip_addr} vm=#{vm_id}")

      $microcloud.submit_event(:vm, vm.uuid, actions[cmd_name], vm.to_hash)

      # TODO log event to the node stream
    end
  end
end
