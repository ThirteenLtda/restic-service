module Restic
    module Service
        module Targets
            class ResticFile < Restic
                def available?
                    @dest.directory?
                end

                def self.normalize_yaml(yaml)
                    if !yaml['dest']
                        raise ArgumentError, "'dest' field not set in rest-file target"
                    end
                    super
                end

                def setup_from_conf(conf, target_yaml)
                    super
                    @dest = Pathname.new(target_yaml['dest'])
                end

                def run
                    super('-r', @dest.to_path, 'backup')
                end
            end
        end
    end
end
