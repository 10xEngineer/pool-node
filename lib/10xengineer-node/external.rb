require 'open4'

module TenxEngineer
  # from di-ruby-lvm / external
  module External

    class CommandFailure < RuntimeError; end

    def execute(cmd)
      output = []
      error = nil

      stat = Open4.popen4(cmd) do |pid, stdin, stdout, stderr|
        while line = stdout.gets
          output << line
        end

        error = stderr.read.strip
      end

      if stat.exited?
        if stat.exitstatus > 0
          raise CommandFailure, "Error (#{stat.exitstatus}): #{error}"
        end
      elsif stat.signaled?
        raise CommandFailure, "Error - signal (#{stat.termsig}) and terminated."
      elsif stat.stopped?
        raise CommandFailure, "Error - signal (#{stat.termsig}) and is stopped."
      end

      if block_given?
        return output.each { |l| yield l}
      else
        return output.join
      end
    end

    module_function :execute
  end
end

