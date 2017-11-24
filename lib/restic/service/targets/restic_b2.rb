module Restic
    module Service
        module Targets
            # A target that backs up to a SFTP target using Restic
            #
            # See README.md for the YAML configuration file format
            class ResticB2 < Restic
                def initialize(name)
                    super

                    @bucket = nil
                    @path = nil
                    @id = nil
                    @key = nil
                end

                def available?
                    ssh = SSHKeys.new
                    actual_keys = ssh.query_keys(@host)
                    valid?(actual_keys)
                end

                def self.normalize_yaml(yaml)
                    %w{bucket path id key}.each do |required_field|
                        if !yaml[required_field]
                            raise Conf::InvalidConfigurationFile, "missing '#{required_field}' field in target"
                        end
                    end
                    super
                end

                def setup_from_conf(conf, yaml)
                    super

                    @bucket = yaml['bucket']
                    @path = yaml['path']
                    @id = yaml['id']
                    @key = yaml['key']
                end

                def available?
                    true
                end

                def run
                    super(Hash['B2_ACCOUNT_ID' => @id, 'B2_ACCOUNT_KEY' => @key], '-r', "b2:#{@bucket}:#{@path}", 'backup')
                end
            end
        end
    end
end
