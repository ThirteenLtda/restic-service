module Restic
    module Service
        module Targets
            module SSHTarget
                def initialize(name)
                    super
                    @key_path = nil
                    @host = nil
                    @username = nil
                    @host_keys = []
                end

                def setup_from_conf(conf, yaml)
                    super
                    @username  = yaml.fetch('username').to_str
                    @host      = yaml.fetch('host').to_str
                    @key_path  = conf.conf_keys_path_for(self)
                    @host_keys = SSHKeys.load_keys_from_file(@key_path)
                end

                def available?
                    ssh = SSHKeys.new
                    actual_keys = ssh.query_keys(@host)
                    valid?(actual_keys)
                end

                def valid?(actual_keys)
                    actual_keys.any? { |k| @host_keys.include?(k) }
                end

                def with_ssh_config
                    ssh = SSHKeys.new
                    ssh_config_name = ssh.ssh_setup_config(
                        name, @username, @host, @key_path)
                    yield(ssh_config_name)
                ensure
                    ssh.ssh_cleanup_config if ssh_config_name
                end
            end
        end
    end
end
