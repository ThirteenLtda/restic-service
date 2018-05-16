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
                     'bandwidth_limit' => nil,
                     'tools' => Hash.new]
            end

            TARGET_CLASS_FROM_TYPE = Hash[
                'restic-b2' => Targets::ResticB2,
                'restic-sftp' => Targets::ResticSFTP,
                'restic-file' => Targets::ResticFile,
                'rclone-b2' => Targets::RcloneB2,
                'rsync' => Targets::Rsync]

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

                yaml['auto_update'] ||= Array.new

                target_names = Array.new
                yaml['targets'] = yaml['targets'].map do |target|
                    if !target['name']
                        raise InvalidConfigurationFile, "missing 'name' field in target"
                    elsif !target['type']
                        raise InvalidConfigurationFile, "missing 'type' field in target"
                    end

                    target_class = target_class_from_type(target['type'])
                    if !target_class
                        raise InvalidConfigurationFile, "target type #{target['type']} does not exist, "\
                            "available targets: #{TARGET_CLASS_FROM_TYPE.keys.sort.join(", ")}"
                    end

                    name = target['name'].to_s
                    if target_names.include?(name)
                        raise InvalidConfigurationFile, "duplicate target name '#{name}'"
                    end

                    target = target.dup
                    target['name'] = name
                    target = target_class.normalize_yaml(target)
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

            # The bandwidth limit in bytes/s
            #
            # Default is nil (none)
            #
            # @return [nil,Integer]
            attr_reader :bandwidth_limit

            def initialize(conf_path)
                @conf_path = conf_path
                @targets = Hash.new
                @period  = 3600
                @tools   = Hash.new
                TOOLS.each do |tool_name|
                    @tools[tool_name] = find_in_path(tool_name)
                end
            end

            BANDWIDTH_SCALES = Hash[
                nil => 1,
                'k' => 1_000,
                'm' => 1_000_000,
                'g' => 1_000_000_000]

            def self.parse_bandwidth_limit(limit)
                if !limit.respond_to?(:to_str)
                    return Integer(limit)
                else
                    match = /^(\d+)\s*(k|m|g)?$/.match(limit.downcase)
                    if match
                        return Integer(match[1]) * BANDWIDTH_SCALES.fetch(match[2])
                    else
                        raise ArgumentError, "cannot interpret '#{limit}' as a valid bandwidth limit, give a plain number in bytes or use the k, M and G suffixes"
                    end
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
                if target = @targets[name]
                    target
                else
                    raise NoSuchTarget, "no target named '#{name}'"
                end
            end

            # Enumerates the targets
            def each_target(&block)
                @targets.each_value(&block)
            end

            # Registers a target
            def register_target(target)
                @targets[target.name] = target
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
                _, available = @tools[tool_name]
                available
            end

            # The full path of a given tool
            #
            # @param [String]
            # @return [Pathname]
            def tool_path(tool_name, only_if_present: true)
                if tool = @tools[tool_name]
                    tool[0] if tool[1] || !only_if_present
                else
                    raise ArgumentError, "cound not find '#{tool_name}'"
                end
            end

            def auto_update_restic_service?
                @auto_update_restic_service
            end

            def auto_update_restic?
                @auto_update_restic
            end

            def restic_platform
                @auto_update_restic
            end

            def auto_update_rclone?
                @auto_update_rclone
            end

            def rclone_platform
                @auto_update_rclone
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
                @bandwidth_limit = if limit_yaml = yaml['bandwidth_limit']
                                       Conf.parse_bandwidth_limit(limit_yaml)
                                   end

                yaml['auto_update'].each do |update_target, do_update|
                    if update_target == 'restic-service'
                        @auto_update_restic_service = do_update
                    elsif update_target == 'restic'
                        @auto_update_restic = do_update
                    elsif update_target == 'rclone'
                        @auto_update_rclone = do_update
                    end
                end

                yaml['targets'].each do |yaml_target|
                    type = yaml_target['type']
                    target_class = Conf.target_class_from_type(type)
                    target = target_class.new(yaml_target['name'])
                    target.setup_from_conf(self, yaml_target)
                    register_target(target)
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
                    end

                    exists = tool_path.file?
                    STDERR.puts "#{tool_path} does not exist" unless exists
                    @tools[tool_name] = [tool_path, exists]
                end
            end
        end
    end
end
