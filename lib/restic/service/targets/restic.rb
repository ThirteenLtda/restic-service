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
                    @forget         = parse_forget_setup(yaml['forget'] || Hash.new)
                end

                Forget = Struct.new :prune, :tags, :hourly, :daily, :weekly, :monthly, :yearly do
                    def prune?
                        prune
                    end
                end
                FORGET_DURATION_KEYS = %w{tags hourly daily weekly monthly yearly}
                FORGET_KEYS = ['prune', *FORGET_DURATION_KEYS].freeze
                def parse_forget_setup(setup)
                    parsed = Forget.new true, []
                    if (invalid_key = setup.find { |k, _| !FORGET_KEYS.include?(k) })
                        raise ArgumentError, "#{invalid_key} is not a valid key within "\
                            "'forget', valid keys are: #{FORGET_KEYS.join(", ")}"
                    end

                    FORGET_KEYS.each do |key|
                        parsed[key] = setup.fetch(key, key == "prune")
                    end
                    parsed
                end

                def run_backup(*args, **options)
                    extra_args = []
                    if one_filesystem?
                        extra_args << '--one-file-system'
                    end

                    run_restic(*args, *extra_args,
                           *@excludes.flat_map { |e| ['--exclude', e] },
                           *@includes)
                end

                def run_restic(*args, **options)
                    home = ENV['HOME'] || '/root'
                    env = if args.first.kind_of?(Hash)
                              env = args.shift
                          else
                              env = Hash.new
                          end

                    extra_args = []
                    if @bandwidth_limit
                        limit_KiB = @bandwidth_limit / 1000 
                        extra_args << '--limit-download' << limit_KiB.to_s << '--limit-upload' << limit_KiB.to_s
                    end

                    ionice_args = []
                    if @io_class != 3
                        ionice_args << '-n' << @io_priority.to_s
                    end

                    system(Hash['HOME' => home, 'RESTIC_PASSWORD' => @password].merge(env),
                           'ionice', '-c', @io_class.to_s, *ionice_args,
                           'nice', "-#{@cpu_priority}",
                           @restic_path.to_path, *args, *extra_args, in: :close, **options)
                end

                def run_forget(*args)
                    extra_args = []
                    FORGET_DURATION_KEYS.each do |key|
                        arg_key =
                            if key == "tags" then "tag"
                            else key
                            end
                        if value = @forget[key]
                            extra_args << "--keep-#{arg_key}" << value.to_s
                        end
                    end
                    if @forget.prune?
                        extra_args << "--prune"
                        puts "PRUNE"
                    end
                    run_restic(*args, *extra_args)
                end
            end
        end
    end
end
