require '10xengineer-node/external'

module Labs
	module Snapshots
		def snapshot_detail(entry)
			snapshot_entry = entry.split(" ")

			name_ex = snapshot_entry[0].match /^lxc\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})@(.*)$/

			name = name_ex.captures.last
			used_size = (snapshot_entry[3] << "B").human_size_to_number
    		real_size = (snapshot_entry[1] << "B").human_size_to_number

    		snapshot = {
    			:name => name,
    			:used_size => used_size || 0,
    			:real_size => real_size || 0
    		}

			return snapshot
		end

		def details(machine_id, name)
			res = TenxEngineer::External.execute("/usr/bin/sudo /sbin/zfs list -r -t snapshot -H lxc/#{machine_id}@#{name}")

			entry = res.split("\n").first

			snapshot_detail(entry)
		end

		def for_machine(machine_id)
			# zfs list -r -t snapshot lxc/e9cecf50-00b1-0130-559c-080027ca18f0 -H

			res = TenxEngineer::External.execute("/usr/bin/sudo /sbin/zfs list -r -t snapshot -H lxc/#{machine_id}")

			snapshots = []

			entries = res.split("\n")
			entries.each do |entry|
        		snapshots << snapshot_detail(entry)
        	end

        	snapshots
		end

		module_function :snapshot_detail
		module_function :details
		module_function :for_machine
	end
end