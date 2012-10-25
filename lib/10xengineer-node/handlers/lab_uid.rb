# setup default 'lab' user

TenxEngineer::External.execute("chroot #{@rootfs} useradd --create-home -s /bin/bash --uid 1000 lab")
TenxEngineer::External.execute("echo \"lab:lab\" | chroot #{@rootfs} chpasswd")
