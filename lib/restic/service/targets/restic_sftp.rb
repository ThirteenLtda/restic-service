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
                    %w{host username path password}.each do |required_field|
                        if !yaml[required_field]
                            raise Conf::InvalidConfigurationFile, "missing '#{required_field}' field in target"
                        end
                    end
                    super
                end

                def setup_from_conf(conf, yaml)
                    @target_name = yaml['name']
                    @key_path    = conf.conf_keys_path_for(self)
                    @host_keys = SSHKeys.load_keys_from_file(@key_path)
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
                    current_home = ENV['HOME']
                    ENV['HOME'] = current_home || '/root'

                    ssh = SSHKeys.new
                    ssh_config_name = ssh.ssh_setup_config(@target_name, @username, @host, @key_path)

                    super('-r', "sftp:#{ssh_config_name}:#{@path}", 'backup')
                ensure
                    ssh.ssh_cleanup_config
                    ENV['HOME'] = current_home
                end
            end
        end
    end
end
