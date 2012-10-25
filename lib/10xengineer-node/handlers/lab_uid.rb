# setup default 'lab' user

TenxEngineer::External.execute("chroot #{@rootfs} useradd --create-home -s /bin/bash --uid 1000 lab")
TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} chpasswd")
TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} adduser lab sudo")

sudoers_t = File.join(File.dirname(__FILE__), '../templates/sudoers.erb')
erb = Erubis::Eruby.new(File.read(sudoers_t))

suders_f = File.join(@rootfs, "/etc/sudoers")
File.open(suders_f, 'w') {|f| f.write(erb.result(binding()))}

if @data[:keys]
	TenxEngineer::External.execute("chroot #{@rootfs} mkdir /home/lab/.ssh")

	auth_keys_file = File.join(@rootfs, "/home/lab/.ssh/authorized_keys")
	File.open(auth_keys_file, 'w') { |f| f.puts @data[:keys]}

	TenxEngineer::External.execute("chroot #{@rootfs} chown -R lab /home/lab/.ssh")
end
