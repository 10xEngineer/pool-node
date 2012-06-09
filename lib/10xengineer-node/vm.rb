require 'yajl'
require 'time'

module TenxEngineer
  module Node
    class VM
      attr_accessor :id, :state, :pool, :type, :options, :created_at, :updated_at

      def initialize(id, state, pool, type, options = {}, created_at = Time.now, updated_at = Time.now)
        @id = id
        @state = state
        @pool = pool
        @type = type
        @options = options
        @created_at = created_at
        @updated_at = updated_at
      end

      def touch
        @updated_at = Time.now
      end

      def save!
        vm_file = "#{TenxEngineer::Node::ROOT}/data_bags/vms/#{id}.json"

        open(vm_file, "w") { |f| f << vm.to_json }
      end

      def self.from_json(json)
        h = Yajl::Parser.parse(json)

        VM.new(h["id"], h["state"].to_sym, h["pool"], h["type"], h["options"], Time.parse(h["created_at"]), Time.parse(h["updated_at"]))
      end

      def to_json
        hash = {
          :id => @id,
          :state => @state,
          :pool => @pool,
          :type => @type,
          :options => @options,
          :created_at => @created_at.iso8601,
          :updated_at => @updated_at.iso8601
        }

        Yajl::Encoder.encode(hash)
      end
    end
  end
end
