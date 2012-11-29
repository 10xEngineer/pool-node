# encoding: utf-8
require '10xengineer-node/external'
require '10xengineer-node/utils'
require 'erubis'
require 'rbconfig'

class ConfigFactory
	def initialize(vm_dir, metadata)
		@vm_dir = vm_dir
		@rootfs = File.join(@vm_dir, "rootfs")
		@handlers = {} 
		@metadata = metadata

		load
	end

	def load
		# TODO global vs template specific handlers (override global)

		location = File.join(File.dirname(__FILE__), "handlers/*")
		classes = Dir.glob(location)
		classes.each do |handler_class|
			next unless File.directory?(handler_class)
			class_name = File.basename handler_class

			@handlers[class_name] = {}

			class_files_location = File.join(File.dirname(__FILE__), "handlers/#{class_name}/*.rb")
			handler_files = Dir.glob(class_files_location)
			handler_files.each do |handler_f|
				name = File.basename(handler_f, ".rb")

				@handlers[class_name][name] = handler_f
			end
		end
	end

	def run(handler, data)
		@data = data
		# TODO run

		#@handlers[handler]
		priority = []
		priority << @metadata["handler_class"]
		priority << "default"

		handler_file = nil
		priority.each do |handler_class|
			if @handlers[handler_class][handler]
				handler_file = @handlers[handler_class][handler]
				break
			end
		end

		raise "Undefined handler '#{handler} for class '#{@metadata["handler_class"]}" unless handler_file

		begin
			proc = Proc.new {}
			eval(File.open(handler_file).read, proc.binding, handler_file)
		rescue => e
			puts "Configuration handler=#{handler} exception=#{e.message}"

			# TODO
		end

		@data = nil
	end
end


