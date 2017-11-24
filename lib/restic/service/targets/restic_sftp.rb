module Restic
    module Service
        module Targets
            # A target that backs up to a SFTP target using Restic
            #
            # See README.md for the YAML configuration file format
            class ResticSFTP < Restic
                def initialize(name)
                    super
                    @host = nil
                    @username = nil
                    @path = nil
                    @host_keys = []
                end

                def available?
                    ssh = SSHKeys.new
                    actual_keys = ssh.query_keys(@host)
                    valid?(actual_keys)
                end

                def self.normalize_yaml(yaml)
                    if !yaml['host']
                        raise Conf::InvalidConfigurationFile, "missing 'host' field in target"
                    end
                    super
                end

                def setup_from_conf(conf, yaml)
                    key_path   = conf.conf_keys_path_for(self)
                    @host_keys = SSHKeys.load_keys_from_file(key_path)
                    @host      = yaml['host'].to_str
                    @username  = yaml['username'].to_str
                    @path      = yaml['path'].to_str
                    @password  = yaml['password'].to_str
                    super
                end

                def valid?(actual_keys)
                    actual_keys.any? { |k| @host_keys.include?(k) }
                end

                def run
                    super('-r', "sftp:#{@username}@#{@host}:#{@path}", 'backup')
                end
            end
        end
    end
end
