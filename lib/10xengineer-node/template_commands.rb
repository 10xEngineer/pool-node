require 'mixlib/shellout'
require 'logger'
require 'yajl'
require 'zfs'

log = Logger.new(STDOUT)
log.level = Logger::WARN

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
  		datasets.each do |ds_list|
  			rec = ds_list.split(' ')
  			components = rec[0].split('/')

  			# /lxc/_templates/owner/template-name
  			next unless components.length == 4

  			# hardcoded owner _default
  			next unless components[2] == '_default'

  			templates << {
  				:name => components[3],
  				:mountpoint => rec[1]
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
	  		puts template[:name]
	  	end
	end
  end
end
