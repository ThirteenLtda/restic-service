module Restic
    module Service
        module Targets
            # A target that backs up to a SFTP target using Restic
            #
            # See README.md for the YAML configuration file format
            class ResticSFTP < Restic
                include SSHTarget

                def initialize(name)
                    super
                    @username = nil
                    @path = nil
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
                    super
                    @target_name = yaml['name']
                    @username  = yaml['username'].to_str
                    @path      = yaml['path'].to_str
                    @password  = yaml['password'].to_str
                    super
                end

                def run
                    with_ssh_config do |ssh_config_name|
                        run_backup('-r', "sftp:#{ssh_config_name}:#{@path}", 'backup')
                    end
                end

                def forget
                    with_ssh_config do |ssh_config_name|
                        run_forget('-r', "sftp:#{ssh_config_name}:#{@path}", 'forget')
                    end
                end
            end
        end
    end
end
