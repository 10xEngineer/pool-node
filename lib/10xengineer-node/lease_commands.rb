require '10xengineer-node/vm'
require '10xengineer-node/microcloud'

# TODO simulate :old 

[:add, :del, :old].each do |cmd_name|
  command cmd_name do |c|
    c.action do |args, options|

      # additional parameters
      mac_addr = args.shift
      ip_addr = args.shift
      vm_id = args.shift

      vm = TenxEngineer::Node::VM.load(vm_id)
      puts vm.inspect

      if cmd_name == :add
        vm.ip_addr = ip_addr
        vm.mac_addr = mac_addr
      else
        vm.ip_addr = nil
        vm.mac_addr = nil
      end

      vm.save!

      $microcloud.send("vm_#{cmd_name}", vm)

      # TODO log event to the node stream
    end
  end
end
