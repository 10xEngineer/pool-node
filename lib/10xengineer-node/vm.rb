require 'yajl'
require 'time'

module TenxEngineer
  module Node
    class VM
      attr_accessor :uuid, :state, :pool, :type, :descriptor, 
        :created_at, :updated_at

      def initialize(uuid, state, pool, type, descriptor = {}, created_at = Time.now, updated_at = Time.now)
        @uuid = uuid
        @state = state
        @pool = pool
        @type = type
        @descriptor = descriptor
        @created_at = created_at
        @updated_at = updated_at
      end

      def touch
        @updated_at = Time.now
      end

      def save!
        vm_file = VM.vm_file(uuid)

        touch

        open(vm_file, "w") { |f| f << self.to_json }
      end

      def self.load(uuid)
        VM.from_json(File.read(VM.vm_file(uuid)))
      end

      def self.from_json(json)
        h = Yajl::Parser.parse(json)

        vm = VM.new(h["uuid"], h["state"].to_sym, h["pool"], h["type"], h["descriptor"], Time.parse(h["created_at"]), Time.parse(h["updated_at"]))

        vm
      end

      def self.vm_storage
        File.join(TenxEngineer::Node::ROOT, "data_bags/vms")
      end

      def self.vm_file(uuid)
        File.join(vm_storage, "#{uuid}.json")
      end

      def to_hash
        hash = {
          :uuid => @uuid,
          :state => @state,
          :pool => @pool,
          :type => @type,
          :descriptor => @descriptor,
          :created_at => @created_at.iso8601,
          :updated_at => @updated_at.iso8601
        }

        hash
      end

      def to_json
        Yajl::Encoder.encode(self.to_hash)
      end

      def to_s
        out = []
        out << "UUID: #{@uuid}"
        out << "State: #{@state}"
        out << "Type: #{@type}"
        out << "IP: #{@descriptor[:ip_addr]}"

        out.join("\n")
      end
    end
  end
end
