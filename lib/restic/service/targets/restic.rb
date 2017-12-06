module Restic
    module Service
        module Targets
            # Base class for all restic-based targets
            #
            # See README.md for the YAML configuration file format
            class Restic < Base
                def initialize(name)
                    super

                    @password = nil
                    @includes = []
                    @excludes = []
                    @one_filesystem = false

                    @io_class     = 3
                    @io_priority  = 0
                    @cpu_priority = 19
                end

                def one_filesystem?
                    @one_filesystem
                end

                def self.normalize_yaml(yaml)
                    yaml = Hash['includes' => [],
                                'excludes' => [],
                                'one_filesystem' => false,
                                'io_class' => 3,
                                'io_priority' => 0,
                                'cpu_priority' => 19].merge(yaml)
                    if yaml['includes'].empty?
                        raise Conf::InvalidConfigurationFile, "nothing to backup"
                    elsif !yaml['password']
                        raise Conf::InvalidConfigurationFile, "no password field"
                    end
                    yaml
                end

                def setup_from_conf(conf, yaml)
                    super

                    @restic_path    = conf.tool_path('restic')
                    @password       = yaml['password']
                    @includes       = yaml['includes'] || Array.new
                    @excludes       = yaml['excludes'] || Array.new
                    @one_filesystem = !!yaml['one_filesystem']
                    @io_class       = Integer(yaml['io_class'])
                    @io_priority    = Integer(yaml['io_priority'])
                    @cpu_priority   = Integer(yaml['cpu_priority'])
                end

                def run(*args)
                    old_home = ENV['HOME']
                    ENV['HOME'] = old_home || '/root'

                    env = if args.first.kind_of?(Hash)
                              env = args.shift
                          else
                              env = Hash.new
                          end

                    ionice_args = []
                    if @io_class != 3
                        ionice_args << '-n' << @io_priority.to_s
                    end

                    extra_args = []
                    if one_filesystem?
                        extra_args << '--one-file-system'
                    end
                    if @bandwidth_limit
                        limit_KiB = @bandwidth_limit / 1000 
                        extra_args << '--limit-download' << limit_KiB.to_s << '--limit-upload' << limit_KiB.to_s
                    end

                    system(Hash['RESTIC_PASSWORD' => @password].merge(env),
                           'ionice', '-c', @io_class.to_s, *ionice_args,
                           'nice', "-#{@cpu_priority}",
                           @restic_path.to_path, *args, *extra_args,
                           *@excludes.flat_map { |e| ['--exclude', e] },
                           *@includes, in: :close)
                ensure
                    ENV['HOME'] = old_home
                end
            end
        end
    end
end
