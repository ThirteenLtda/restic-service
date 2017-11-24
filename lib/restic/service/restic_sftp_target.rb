module Restic
    module Service
        # A target that backs up to a SFTP target using Restic
        #
        # See README.md for the YAML configuration file format
        class ResticSFTPTarget
            attr_reader :name

            def initialize(name)
                @name = name

                @host = nil
                @host_keys = []

                @repo = nil
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

            def available?
                ssh = SSHKeys.new
                actual_keys = ssh.query_keys(@host)
                valid?(actual_keys)
            end

            def self.normalize_yaml(yaml)
                if !yaml['host']
                    raise Conf::InvalidConfigurationFile, "missing 'host' field in target"
                end
                yaml = Hash['includes' => [],
                            'excludes' => [],
                            'one_filesystem' => false,
                            'io_class' => 3,
                            'io_priority' => 0,
                            'cpu_priority' => 19].merge(yaml)
                if yaml['includes'].empty?
                    raise Conf::InvalidConfigurationFile, "nothing to backup"
                end
                yaml
            end

            def setup_from_conf(conf, yaml)
                @restic_path = conf.tool_path('restic')

                key_path = conf.conf_keys_path_for(self)
                @host           = yaml['host'].to_str
                @host_keys      = SSHKeys.load_keys_from_file(key_path)
                @repo           = yaml['repo'].to_str
                @password       = yaml['password'].to_str
                @includes       = yaml['includes'] || Array.new
                @excludes       = yaml['excludes'] || Array.new
                @one_filesystem = yaml['one_filesystem']
                @io_class       = Integer(yaml['io_class'])
                @io_priority    = Integer(yaml['io_priority'])
                @cpu_priority   = Integer(yaml['cpu_priority'])
            end

            def valid?(actual_keys)
                actual_keys.any? { |k| @host_keys.include?(k) }
            end

            def run
                ionice_args = []
                if @io_class != 3
                    ionice_args << '-n' << @io_priority.to_s
                end
                extra_args = []
                if one_filesystem?
                    extra_args << '--one-file-system'
                end
                system(Hash['RESTIC_PASSWORD' => @password],
                       'ionice', '-c', @io_class.to_s, *ionice_args,
                       'nice', "-#{@cpu_priority}",
                       @restic_path.to_path, '-r', @repo, 'backup',
                       *extra_args,
                       *@excludes.flat_map { |e| ['--exclude', e] },
                       *@includes, in: :close)
            end
        end
    end
end

