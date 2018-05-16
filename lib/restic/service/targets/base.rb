module Restic
    module Service
        module Targets
            class Base
                attr_reader :name

                def initialize(name)
                    @name = name
                    @bandwidth_limit = nil
                    @io_class = nil
                    @io_priority = nil
                    @cpu_priority = nil
                end

                def self.normalize_yaml(yaml)
                    yaml.dup
                end

                def available?
                    true
                end

                def setup_from_conf(conf, yaml)
                    @bandwidth_limit =
                        if limit = yaml.fetch('bandwidth_limit', conf.bandwidth_limit)
                            Conf.parse_bandwidth_limit(limit)
                        end
                    if (io_class = yaml['io_class'])
                        @io_class = Integer(io_class)
                    end
                    if (io_priority = yaml['io_priority'])
                        @io_priority = Integer(io_priority)
                    end
                    if (cpu_priority = yaml['cpu_priority'])
                        @cpu_priority = Integer(cpu_priority)
                    end
                end

                def nice_commands
                    result = []
                    if @io_class
                        result << 'ionice' << '-c' << @io_class.to_s
                        if @io_priority
                            result << '-n' << @io_priority.to_s
                        end
                    end
                    if @cpu_priority
                        result << "nice" << "-#{@cpu_priority}"
                    end
                    result
                end
            end
        end
    end
end

