module Restic
    module Service
        # The overall service configuration
        #
        # This is the API side of the service configuration. The configuration
        # is usually stored on disk in YAML and 
        #
        # The YAML format is as follows:
        #
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
                Hash['targets' => []]
            end

            # Normalizes and validates a configuration hash, as stored in YAML
            #
            # @raise [InvalidConfigurationFile]
            def self.normalize_yaml(yaml)
                yaml = Conf.default_conf.merge(yaml)
                target_names = Array.new
                yaml['targets'].each do |target|
                    if !target['name']
                        raise InvalidConfigurationFile, "missing 'name' field in target"
                    elsif !target['host']
                        raise InvalidConfigurationFile, "missing 'host' field in target"
                    end

                    name = target['name'].to_s
                    if target_names.include?(name)
                        raise InvalidConfigurationFile, "duplicate target name '#{name}'"
                    end
                    target_names << name
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

            def initialize
                @targets = Hash.new
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
            
            # Add the information stored in a YAML-like hash into this
            # configuration
            #
            # @param [Hash] the configuration, following the documented
            #   configuration format (see {Conf})
            # @return [void]
            def load_from_yaml(yaml)
                yaml['targets'].each do |target|
                    @targets[target['name']] =
                        Target.new(target['name'], target['host'])
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
                        target.keys = SSHKeys.load_keys_from_file(key_path)
                    end
                end
            end
        end
    end
end

