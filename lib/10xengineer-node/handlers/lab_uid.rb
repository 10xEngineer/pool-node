# setup default 'lab' user

TenxEngineer::External.execute("chroot #{@rootfs} useradd --create-home -s /bin/bash --uid 1000 lab")
TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} chpasswd")

if @data[:keys]
	TenxEngineer::External.execute("chroot #{@rootfs} mkdir /home/lab/.ssh")

	auth_keys_file = File.join(@rootfs, "/home/lab/.ssh/authorized_keys")
	File.open(auth_keys_file, 'w') { |f| f.puts @data[:keys]}

	TenxEngineer::External.execute("chroot #{@rootfs} chown -R lab /home/lab/.ssh")
end
