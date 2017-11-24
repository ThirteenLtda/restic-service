module Restic
    module Service
        # The overall service configuration
        #
        # This is the API side of the service configuration. The configuration
        # is usually stored on disk in YAML and
        #
        # The YAML format is as follows:
        #
        #   # The path to the underlying tools
        #   tools:
        #     restic: /opt/restic
        #     rclone: /opt/rclone
        #
        #   # The targets. The only generic parts of a target definition
        #   # are the name and type. The rest is target-specific
        #   targets:
        #     - name: a_restic_sftp_target
        #       type: restic-sftp
        #
        # See the README.md for more details about available targets
        class Conf
            # Exception raised when using a target name that does not exist
            class NoSuchTarget < RuntimeError; end
            # Exception raised when an invalid configuration file is loaded
            class InvalidConfigurationFile < RuntimeError; end

            # The default (empty) configuration
            def self.default_conf
                Hash['targets' => [],
                     'period' => 3600,
                     'tools' => Hash.new]
            end

            TARGET_CLASS_FROM_TYPE = Hash[
                'restic-b2' => Targets::ResticB2,
                'restic-sftp' => Targets::ResticSFTP]

            TOOLS = %w{restic rclone}

            # Returns the target class that will handle the given target type
            #
            # @param [String] type the type as represented in the YAML file
            def self.target_class_from_type(type)
                if target_class = TARGET_CLASS_FROM_TYPE[type]
                    return target_class
                else
                    raise InvalidConfigurationFile, "target type #{type} does not exist, available targets: #{TARGET_CLASS_FROM_TYPE.keys.sort.join(", ")}"
                end
            end

            # Normalizes and validates a configuration hash, as stored in YAML
            #
            # @raise [InvalidConfigurationFile]
            def self.normalize_yaml(yaml)
                yaml = default_conf.merge(yaml)
                TOOLS.each do |tool_name|
                    yaml['tools'][tool_name] ||= tool_name
                end

                target_names = Array.new
                yaml['targets'] = yaml['targets'].map do |target|
                    if !target['name']
                        raise InvalidConfigurationFile, "missing 'name' field in target"
                    end

                    target_class = TARGET_CLASS_FROM_TYPE[target['type']]
                    if !target_class
                        raise InvalidConfigurationFile, "target type #{target['type']} does not exist, available targets: #{TARGET_CLASS_FROM_TYPE.keys.sort.join(", ")}"
                    end

                    name = target['name'].to_s
                    if target_names.include?(name)
                        raise InvalidConfigurationFile, "duplicate target name '#{name}'"
                    end

                    target = target_class.normalize_yaml(target.dup)
                    target['name'] = name
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
                    return Conf.new(Pathname.new(""))
                end

                yaml = YAML.load(path.read) || Hash.new
                yaml = normalize_yaml(yaml)

                conf = Conf.new(path.dirname)
                conf.load_from_yaml(yaml)
                conf
            end

            # The configuration path
            #
            # @return [Pathname]
            attr_reader :conf_path

            # The polling period in seconds
            #
            # Default is 1h (3600s)
            #
            # @return [Integer]
            attr_reader :period

            def initialize(conf_path)
                @conf_path = conf_path
                @targets = Hash.new
                @period  = 3600
                @tools   = Hash.new
                TOOLS.each do |tool_name|
                    @tools[tool_name] = find_in_path(tool_name)
                end
            end

            # The path to the key file for the given target
            def conf_keys_path_for(target)
                conf_path.join("keys", "#{target.name}.keys")
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

            # Checks whether a given tool is available
            #
            # @param [String]
            # @return [Boolean]
            def tool_available?(tool_name)
                @tools.has_key?(tool_name)
            end

            # The full path of a given tool
            #
            # @param [String]
            # @return [Pathname]
            def tool_path(tool_name)
                @tools.fetch(tool_name)
            end

            # Add the information stored in a YAML-like hash into this
            # configuration
            #
            # @param [Hash] the configuration, following the documented
            #   configuration format (see {Conf})
            # @return [void]
            def load_from_yaml(yaml)
                load_tools_from_yaml(yaml['tools'])
                @period = Integer(yaml['period'])

                yaml['targets'].each do |yaml_target|
                    type = yaml_target['type']
                    target_class = Conf.target_class_from_type(type)
                    target = target_class.new(yaml_target['name'])
                    target.setup_from_conf(self, yaml_target)
                    @targets[target.name] = target
                end
            end

            # @api private
            #
            # Helper for {#load_from_yaml}
            def load_tools_from_yaml(yaml)
                TOOLS.each do |tool_name|
                    tool_path = Pathname.new(yaml[tool_name])
                    if tool_path.relative?
                        tool_path = find_in_path(tool_path)
                        if !tool_path
                            STDERR.puts "cannot find path to #{tool_name}"
                        end
                    end
                    if tool_path
                        @tools[tool_name] = tool_path
                    else
                        @tools.delete(tool_name)
                    end
                end
            end

        end
    end
end
