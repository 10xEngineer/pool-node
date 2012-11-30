# setup default 'lab' user

data_shell = @data[:shell] || "bash"

case data_shell
when "zsh"
	shell = "/bin/zsh"
when "ksh"
	shell = "/bin/ksh"
else
	shell = "/bin/bash"
end


TenxEngineer::External.execute("chroot #{@rootfs} useradd --create-home --uid 1000 -s #{shell} lab")
TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} chpasswd")
if data[:class] == "ubuntu"
	TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} adduser lab sudo")
elsif data[:class] == "rhel"
	TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} groupadd sudo")
	TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} usermod -G sudo lab")
end

# TODO only if no dotfiles provided
if data_shell == "zsh"
	zshrc_t = File.join(File.dirname(__FILE__), '../../templates/zshrc.erb')
	erb = Erubis::Eruby.new(File.read(zshrc_t))

	zshrc_f = File.join(@rootfs, "/home/lab/.zshrc")
	File.open(zshrc_f, 'w') {|f| f.write(erb.result(binding()))}

	TenxEngineer::External.execute("chroot #{@rootfs} chown -R lab:lab /home/lab/.zshrc")
end

sudoers_t = File.join(File.dirname(__FILE__), '../../templates/sudoers.erb')
erb = Erubis::Eruby.new(File.read(sudoers_t))

suders_f = File.join(@rootfs, "/etc/sudoers")
File.open(suders_f, 'w') {|f| f.write(erb.result(binding()))}

if @data[:keys]
	TenxEngineer::External.execute("chroot #{@rootfs} mkdir /home/lab/.ssh")

	auth_keys_file = File.join(@rootfs, "/home/lab/.ssh/authorized_keys")
	File.open(auth_keys_file, 'w') { |f| f.puts @data[:keys]}

	TenxEngineer::External.execute("chroot #{@rootfs} chown -R lab /home/lab/.ssh")
end
