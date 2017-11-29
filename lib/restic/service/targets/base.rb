module Restic
    module Service
        module Targets
            class Base
                attr_reader :name

                def initialize(name)
                    @name = name

                    @bandwidth_limit = nil
                end

                def setup_from_conf(conf, yaml)
                    @bandwidth_limit =
                        if limit = yaml.fetch('bandwidth_limit', conf.bandwidth_limit)
                            Conf.parse_bandwidth_limit(limit)
                        end
                end
            end
        end
    end
end

