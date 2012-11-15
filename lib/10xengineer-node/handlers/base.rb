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
config_t = File.join(File.dirname(__FILE__), '../templates/interfaces.erb')
erb = Erubis::Eruby.new(File.read(config_t))

interfaces_f = File.join(@rootfs, "/etc/network/interfaces")
File.open(interfaces_f, 'w') {|f| f.write(erb.result(binding()))}

# fstab
fstab_f = File.join(@vm_dir, "fstab")
fstab = <<-EOH
proc            proc         proc    nodev,noexec,nosuid 0 0
sysfs           sys          sysfs defaults  0 0
devtmpfs        dev          devtmpfs defaults 0 0
EOH

File.open(fstab_f, 'w') {|f| f.write(fstab)}

# motd
motd_help_text_f = File.join(@rootfs, "/etc/update-motd.d/10-help-text")
motd = <<-EOH
#!/bin/sh
[ -r /etc/lsb-release ] && . /etc/lsb-release

echo 
echo "* Documentation & Support - http://help.10xengineer.me/"
echo
EOH

File.open(motd_help_text_f, 'w') {|f| f.write(motd)}

# disable password based login
TenxEngineer::External.execute("chroot #{@rootfs} sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config")
