module Restic
    module Service
        module Targets
            module B2
                def available?
                    true
                end

                def self.normalize_yaml(yaml)
                    %w{bucket path id key}.each do |required_field|
                        if !yaml[required_field]
                            raise Conf::InvalidConfigurationFile, "missing '#{required_field}' field in target"
                        end
                    end
                    yaml
                end

                def initialize(*args)
                    super

                    @bucket = nil
                    @path = nil
                    @id = nil
                    @key = nil
                end

                def setup_from_conf(conf, yaml)
                    super

                    @bucket = yaml['bucket']
                    @path   = yaml['path']
                    @id     = yaml['id']
                    @key    = yaml['key']
                end
            end
        end
    end
end
