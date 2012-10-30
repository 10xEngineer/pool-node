require '10xengineer-node/external'

module Labs
	module Snapshots
		def for_machine(machine_id)
			# zfs list -r -t snapshot lxc/e9cecf50-00b1-0130-559c-080027ca18f0 -H

			res = TenxEngineer::External.execute("/usr/bin/sudo /sbin/zfs list -r -t snapshot -H lxc/#{machine_id}")

			snapshots = []

			entries = res.split("\n")
			entries.each do |entry|
				snapshot_entry = entry.split(" ")

				name_ex = snapshot_entry[0].match /^lxc\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})@(.*)$/
				next unless name_ex

				name = name_ex.captures.last
				used_size = (snapshot_entry[3] << "B").human_size_to_number
        		real_size = (snapshot_entry[1] << "B").human_size_to_number

        		snapshot = {
        			:name => name,
        			:used_size => used_size,
        			:real_size => real_size
        		}

        		snapshots << snapshot
        	end

        	snapshots
		end

		module_function :for_machine
	end
end