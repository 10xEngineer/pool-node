require "10xengineer-node/version"

require 'yajl'
require 'syslog'
require 'commander'
require 'commander/delegates'

require "10xengineer-node/utils"

#
# snippet from commander:lib/commander/import.rb needed when manually calling
# run! instead of relying on at_exit { run! } (sic!).
#
include Commander::UI
include Commander::UI::AskForClass
include Commander::Delegates

$terminal.wrap_at = HighLine::SystemExtensions.terminal_size.first - 5 rescue 80 if $stdin.tty?

module TenxEngineer
  module Node

    # Your code goes here...
  end
end
