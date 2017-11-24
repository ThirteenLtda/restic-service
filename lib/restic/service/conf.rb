module Restic
    module Service
        # The overall service configuration
        #
        # This is the API side of the service configuration. The configuration
        # is usually stored on disk in YAML and 
        #
        # The YAML format is as follows:
        #
        #   # The path to restic itself, defaults to look for 'restic' in PATH
        #   restic: restic
        #   # The polling period in seconds
        #   period: 3600
        #   # The IO class for the restic process (default is 'idle' (3), see
        #   # the ionice manpage)
        #   io_class: 3
        #   # The IO priority for the restic process (ignored for the
        #   # default idle class, see the ionice manpage)
        #   io_priority: 0
        #   # The CPU priority for the restic process (default is to give the
        #   # least amount of CPU)
        #   cpu_priority: 19
        #   # The list of targets, add one with the add-target subcommand
        #   targets:
        #   - name: name_of_target
        #     host: hostname_or_ip
        #
        # In addition, each target has an associated file that contains this
        # target's SSH keys, as returned by ssh-keyscan. This is the only
        # mechanism used to authentify the targets.
        class Conf
            # Exception raised when using a target name that does not exist
            class NoSuchTarget < RuntimeError; end
            # Exception raised when an invalid configuration file is loaded
            class InvalidConfigurationFile < RuntimeError; end

            # The default (empty) configuration
            def self.default_conf
                Hash['targets' => [],
                     'period' => 3600,
                     'io_class' => 3,
                     'io_priority' => 0,
                     'cpu_priority' => 19,
                     'restic' => 'restic']
            end

            def self.default_target
                Hash['includes' => [],
                     'excludes' => [],
                     'one_filesystem' => false]
            end

            # Normalizes and validates a configuration hash, as stored in YAML
            #
            # @raise [InvalidConfigurationFile]
            def self.normalize_yaml(yaml)
                yaml = Conf.default_conf.merge(yaml)
                target_names = Array.new
                yaml['targets'] = yaml['targets'].map do |target|
                    if !target['name']
                        raise InvalidConfigurationFile, "missing 'name' field in target"
                    elsif !target['host']
                        raise InvalidConfigurationFile, "missing 'host' field in target"
                    end

                    name = target['name'].to_s
                    if target_names.include?(name)
                        raise InvalidConfigurationFile, "duplicate target name '#{name}'"
                    end

                    target['name'] = name
                    target = default_target.merge(target)
                    target_names << name
                    target
                end
                yaml
            end

            # Load a configuration file
            #
            # @param [Pathname]
            # @return [Conf]
            # @raise (see normalize_yaml)
            def self.load(path)
                if !path.file?
                    return Conf.new
                end

                yaml = YAML.load(path.read) || Hash.new
                yaml = normalize_yaml(yaml)

                conf = Conf.new
                conf.load_from_yaml(yaml)
                conf
            end

            # The polling period in seconds
            #
            # Default is 1h (3600s)
            #
            # @return [Integer]
            attr_reader :period
            # The full path to the restic executable
            #
            # @return [Pathname]
            attr_reader :restic_path

            def initialize
                @targets = Hash.new
                @period = 3600
                @restic_path = find_in_path('restic')
            end

            # Gets a target configuration
            #
            # @param [String] name the target name
            # @return [Target]
            # @raise NoSuchTarget
            def target_by_name(name)
                if target = @targets[target_name]
                    target
                else
                    raise NoSuchTarget, "no target named #{target_name}"
                end
            end

            # Enumerates the targets
            def each_target(&block)
                @targets.each_value(&block)
            end

            # @api private
            #
            # Helper that resolves a binary in PATH
            def find_in_path(name)
                ENV['PATH'].split(File::PATH_SEPARATOR).each do |p|
                    candidate = Pathname.new(p).join(name)
                    if candidate.file?
                        return candidate
                    end
                end
                nil
            end
            
            # Add the information stored in a YAML-like hash into this
            # configuration
            #
            # @param [Hash] the configuration, following the documented
            #   configuration format (see {Conf})
            # @return [void]
            def load_from_yaml(yaml)
                restic = Pathname.new(yaml['restic'])
                if restic.relative?
                    restic = find_in_path(relative = restic)
                    if !restic
                        raise InvalidConfigurationFile, "cannot find #{relative} in PATH=#{ENV['PATH']}"
                    end
                end
                @restic_path = restic
                @period = yaml['period']

                yaml['targets'].each do |yaml_target|
                    target = Target.new(yaml_target['name'], yaml_target['host'])
                    target.setup_backup_target(
                        yaml_target['restic_target'],
                        yaml_target['restic_password'],
                        yaml_target['includes'],
                        excludes: yaml_target['excludes'],
                        one_filesystem: yaml_target['one_filesystem'])

                    %w{io_class io_priority cpu_priority}.each do |option|
                        target.send("#{option}=", yaml_target[option] || yaml[option])
                    end

                    @targets[target.name] = target
                end
            end

            # Load the SSH keys stored on disk
            #
            # @param [Pathname] the path to the directory that contains the
            #   keys. Key files are expected to be named ${TARGET_NAME}.keys
            def load_keys_from_disk(path)
                each_target do |target|
                    key_path = path + "#{target.name}.keys"
                    if !key_path.file?
                        STDERR.puts "No keys for #{target.name}"
                    else
                        target.host_keys = SSHKeys.load_keys_from_file(key_path)
                    end
                end
            end
        end
    end
end

