require 'mixlib/shellout'
require 'logger'
require 'yajl'
require 'zfs'

log = Logger.new(STDOUT)
log.level = Logger::WARN

command :create do |c|
  # FIXME implement
end

command :list do |c|
  c.description = "List available VM templates"

  c.action do |args, options|
  	options.default :owner => "_default"

  	templates = []

  	zfs_list = Mixlib::ShellOut.new("zfs list -H -o name,mountpoint")
  	begin
  		zfs_list.run_command
  		zfs_list.error!

  		datasets = zfs_list.stdout.split("\n")
  		datasets.each do |ds_item|
  			rec = ds_item.split(' ')
  			components = rec[0].split('/')

  			# /lxc/_templates/owner/template-name
  			next unless components.length == 4

        # read metadata
        root_f = "/var/lib"
        metadata_f = File.join(root_f, rec[0], '/metadata.json')

        puts metadata_f
        unless File.exists?(metadata_f)
          Syslog.log(Syslog::LOG_ERR, "invalid template=#{rec[0]} reason='missing metadata.json'")

          next
        end
        metadata = Yajl::Parser.parse(File.open(metadata_f))

  			# hardcoded owner _default
  			next unless components[2] == '_default'

  			templates << {
  				:name => components[3],
  				:mountpoint => rec[1],
          :description => metadata["description"],
          :handlers => metadata["handlers"],
          :maintainer => metadata["maintainer"]
  			}
  		end
	rescue Mixlib::ShellOut::ShellCommandFailed => e
  		Syslog.log(Syslog::LOG_ERR, "cmd=zfs-list failed reason='#{e.message}'")

  		ext_abort e.message
  	end

	if $json
		puts Yajl::Encoder.encode(templates)
	else
	  	templates.each do |template|
	  		puts "#{template[:name]} #{template[:description]}"
	  	end
	end
  end
end
