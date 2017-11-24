module Restic
    module Service
        class Target
            attr_reader :name
            attr_reader :host

            attr_accessor :host_keys

            attr_reader :restic_target
            attr_reader :restic_password
            attr_reader :includes
            attr_reader :excludes

            attr_accessor :io_class
            attr_accessor :io_priority
            attr_accessor :cpu_priority

            def initialize(name, host)
                @name = name
                @host = host
                @io_class = 3
                @io_priority = 0
                @cpu_priority = 19
                @host_keys = Array.new
                @includes = []
                @excludes = []
                @one_filesystem = false
            end

            def setup_backup_target(restic_target, password, includes,
                                    excludes: [],
                                    one_filesystem: false)
                @restic_target = restic_target
                @includes = includes
                @excludes = excludes
                @restic_password = password
                @one_filesystem = one_filesystem
            end

            def valid?(actual_keys)
                actual_keys.any? { |k| host_keys.include?(k) }
            end

            def run(restic_path = Pathname.new('restic'))
                extra_args = []
                if @one_filesystem
                    extra_args << '--one-file-system'
                end
                system(Hash['RESTIC_PASSWORD' => restic_password],
                       'ionice', '-c', io_class.to_s, '-n', io_priority.to_s,
                       'nice', "-#{cpu_priority}",
                       restic_path.to_path, '-r', restic_target, 'backup',
                       *extra_args,
                       *@excludes.flat_map { |e| ['--exclude', e] },
                       *@includes, in: :close)
            end
        end
    end
end

