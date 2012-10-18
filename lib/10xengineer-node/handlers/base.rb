# TODO process all file contents as templates
raise "hostname not provided" unless @data[:hostname]

hostname_f = File.join(@rootfs, "/etc/hostname")

# write hostname
File.open(hostname_f, 'w') { |f| f.write(data[:hostname])}

# hosts file
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

File.open(hosts_f, 'w') {|f| f.write(hosts)}

# network interfaces
interfaces_f = File.join(@rootfs, "/etc/network/interfaces")
interfaces = <<-EOH
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
EOH

File.open(interfaces_f, 'w') {|f| f.write(interfaces)}

# fstab
fstab_f = File.join(@vm_dir, "fstab")
fstab = <<-EOH
proc            proc         proc    nodev,noexec,nosuid 0 0
sysfs           sys          sysfs defaults  0 0
devtmpfs        dev          devtmpfs defaults 0 0
EOH

File.open(fstab_f, 'w') {|f| f.write(fstab)}