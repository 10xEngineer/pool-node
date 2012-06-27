require 'httparty'
require 'yajl'

class Microcloud
  include HTTParty
  format :json

  def initialize(endpoint = nil, config = '/etc/10xeng.yaml')
    unless endpoint
      if File.exists?(config)
        config = YAML::load(File.open(config))

        endpoint = config["hostnode"]["endpoint"]
      end
    end

    raise "No endpoint provided!" unless endpoint

    Microcloud.base_uri HTTParty.normalize_base_uri(endpoint)
  end

  def example
    #options.merge!({:basic_auth => @auth})
  end

  def vm_add(vm)
    body = create_body({
      :action => :start,
      :vm => {
        :id => vm.id,
        :ip_addr => vm.ip_addr
      }
    })

    self.class.post("/vms/#{vm.id}/notify", :body => body)
  end

  def vm_del(vm)
    body = create_body({
      :action => :stop,
      :vm => {
        :id => vm.id
      }
    })

    self.class.post("/vms/#{vm.id}/notify", :body => body)
  end



  # TODO vm_down
private

  def create_body(hash)
    Yajl::Encoder.encode(hash)
  end

end
