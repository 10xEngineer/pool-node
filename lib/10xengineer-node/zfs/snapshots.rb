require '10xengineer-node/external'

module Labs

	module Snapshots
		def snapshot_detail(entry, persistent = false)
			snapshot_entry = entry.split(" ")

			if persistent
				name_ex = snapshot_entry[0].match /^tank\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/
			else
				name_ex = snapshot_entry[0].match /^lxc\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})@(.*)$/
			end

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
			begin

				command = ["/usr/bin/sudo", "zfs", "list"]
				if machine_id
					command << "-r -t snapshot -H lxc/#{machine_id}@#{name}"
				else
					command << "-H tank/#{name}"
				end

				res = TenxEngineer::External.execute(command.join(' '))

				entry = res.split("\n").first

				return snapshot_detail(entry, machine_id.nil?)
			rescue => e
				return nil
			end
		end

		def for_machine(machine_id)
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