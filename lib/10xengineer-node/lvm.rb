require 'lvm'

module TenxEngineer
  module Node
    def volume_group(vgname)
      lvm = LVM::LVM.new(:command => LVM_CMD)

      vg = lvm.volume_groups[vgname]

      vg
    end

    module_function :volume_group
  end
end
