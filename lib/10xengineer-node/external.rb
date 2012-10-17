require 'mixlib/shellout'

module TenxEngineer
  module External

    class CommandFailure < RuntimeError; end

    def execute(cmd)
      shell_out = Mixlib::ShellOut.new(cmd)      
      shell_out.run_command

      if shell_out.status.signaled?
        raise CommandFailure, "Error - signal (#{shell_out.status.termsig}) and terminated"
      elsif shell_out.status.stopped?
        raise CommandFailure, "Error - signal (#{shell_out.status.stopsig}) and is stopped"
      elsif !shell_out.status.success?
        error_message = shell_out.stderr.empty ? (shell_out.stdout.delete_if {|i| i.strip.empty?}).first : shell_out.stderr.split("\n").first
        raise CommandFailure, "Error (#{shell_out.status.exitstatus}"
      end

      if block_given?
        return shell_out.stdout.split("\n").each { |l| yield l}
      else
        return shell_out.stdout
      end
    end

    module_function :execute
  end
end

