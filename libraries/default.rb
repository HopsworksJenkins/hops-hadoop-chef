module Hops
  module Helpers
    def template_ssl_server(generate_jwt = true)
      if (generate_jwt and (node['hops']['rmappsecurity']['jwt']['enabled'].eql?("true") or node['hops']['tls']['enabled'].eql?("true")))
        
        ## Get service JWT, from kagent-chef/libraries
        master_token, renew_tokens = get_service_jwt()
      else
        master_token = ""
        renew_tokens = []
      end

      fqdn = node['fqdn']
      if node['install']['localhost'].casecmp?("true")
        fqdn = "localhost"
      end

      template "#{node['hops']['conf_dir']}/ssl-server.xml" do
        source "ssl-server.xml.erb"
        owner node['hops']['hdfs']['user']
        group node['hops']['secure_group']
        mode "770"
        variables({
                    :master_token => master_token,
                    :renew_tokens => renew_tokens
                  })
        action :create
      end
    end
    
    def service_discovery_enabled()
      exists_local('consul', 'default')
    end
  end
end
