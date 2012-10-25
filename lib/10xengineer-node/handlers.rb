# encoding: utf-8
require '10xengineer-node/external'
require 'erubis'
require 'rbconfig'

class ConfigFactory
	def initialize(vm_dir)
		@vm_dir = vm_dir
		@rootfs = File.join(@vm_dir, "rootfs")
		@handlers = {} 

		load
	end

	def load
		# TODO global vs template specific handlers (override global)
		location = File.join(File.dirname(__FILE__), "handlers/*.rb")
		handler_files = Dir.glob(location)
		handler_files.each do |handler_f|
			name = File.basename(handler_f, ".rb")

			@handlers[name] = handler_f
		end
	end

	def run(handler, data)
		@data = data
		# TODO run

		begin
			proc = Proc.new {}
			eval(File.open(@handlers[handler]).read, proc.binding, @handlers[handler])
		rescue => e
			puts "Configuration handler=#{handler} exception=#{e.message}"

			# TODO
		end

		@data = nil
	end
end


