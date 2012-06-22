require 'yajl'
require 'time'

module TenxEngineer
  module Node
    class VM
      attr_accessor :id, :state, :pool, :type, :descriptor, 
        :created_at, :updated_at, :ip_addr, :mac_addr

      def initialize(id, state, pool, type, descriptor = {}, created_at = Time.now, updated_at = Time.now)
        @id = id
        @state = state
        @pool = pool
        @type = type
        @descriptor = descriptor
        @ip_addr = nil
        @mac_addr = nil
        @created_at = created_at
        @updated_at = updated_at
      end

      def touch
        @updated_at = Time.now
      end

      def save!
        vm_file = VM.vm_file(id)

        touch

        open(vm_file, "w") { |f| f << self.to_json }
      end

      def self.load(id)
        VM.from_json(File.read(VM.vm_file(id)))
      end

      def self.from_json(json)
        h = Yajl::Parser.parse(json)

        vm = VM.new(h["id"], h["state"].to_sym, h["pool"], h["type"], h["descriptor"], Time.parse(h["created_at"]), Time.parse(h["updated_at"]))

        # additional attributes
        %w{ip_addr mac_addr}.each do |attr|
          vm.send("#{attr}=", h[attr])
        end

        vm
      end

      def self.vm_storage
        File.join(TenxEngineer::Node::ROOT, "data_bags/vms")
      end

      def self.vm_file(id)
        File.join(vm_storage, "#{id}.json")
      end

      def to_json
        hash = {
          :id => @id,
          :state => @state,
          :pool => @pool,
          :type => @type,
          :descriptor => @descriptor,
          :ip_addr => @ip_addr,
          :mac_addr => @mac_addr,
          :created_at => @created_at.iso8601,
          :updated_at => @updated_at.iso8601
        }

        Yajl::Encoder.encode(hash)
      end

      def to_s
        out = []
        out << "ID: #{@id}"
        out << "State: #{@state}"
        out << "Type: #{@type}"
        out << "IP: #{@ip_addr}"

        out.join("\n")
      end
    end
  end
end
