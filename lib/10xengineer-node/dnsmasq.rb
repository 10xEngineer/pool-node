def active_leases(lease_db = "/var/lib/misc/dnsmasq.leases")
  leases = {}

  lease_lines = File.read(lease_db).split("\n")
  lease_lines.each do |line|
    cols = line.split(" ")

    lease = {
      :created_at => Time.at(cols[0].to_i),
      :mac => cols[1],
      :ip_address => cols[2]
    }

    leases[cols[3]] = lease
  end

  leases
end
