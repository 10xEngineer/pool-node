require 'yajl'

def ext_abort(reason, json = $json)
  abort (json ? Yajl::Encoder.encode({:reason => reason}) : reason)
end
