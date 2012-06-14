command :add do |c|
  c.action do |args, options|
    # additional parameters
    mac_addr = args.shift
    ip_addr = args.shift
    vm_id = args.shift


  end
end

command :del do |c|
  c.action do |args, options|
  end
end

command :old do |c|
  c.action do |args, options|
  end
end
