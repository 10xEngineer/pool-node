# TODO process all file contents as templates
raise "hostname not provided" unless @data[:hostname]

# network setup
network_t = File.join(File.dirname(__FILE__), '../../templates/rhel/network.erb')
erb = Erubis::Eruby.new(File.read(network_t))

network_f = File.join(@rootfs, "/etc/sysconfig/network-scripts/ifcfg-eth0")
File.open(network_f, 'w') {|f| f.write(erb.result(binding()))}

# hosts
hosts_f = File.join(@rootfs, "/etc/hosts")
hosts = <<-EOH
127.0.0.1   localhost
127.0.1.1   #{@data[:hostname]}

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOH

# fstab
fstab_f = File.join(@vm_dir, "fstab")
fstab = <<-EOH
EOH

File.open(fstab_f, 'w') {|f| f.write(fstab)}

# motd
motd_help_text_f = File.join(@rootfs, "/etc/motd")
motd = <<-EOH
#!/bin/sh
echo 
echo "* Documentation & Support - http://help.10xengineer.me/"
echo
EOH

