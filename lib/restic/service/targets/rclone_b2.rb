module Restic
    module Service
        module Targets
            class RcloneB2 < Base
                include B2

                def self.normalize_yaml(yaml)
                    yaml = B2.normalize_yaml(yaml)
                    if !yaml['src']
                        raise Conf::InvalidConfigurationFile, "no src field provided for rclone-b2"
                    elsif !File.directory?(yaml['src'])
                        raise Conf::InvalidConfigurationFile, "provided rclone-b2 source #{yaml['src']} does not exist"
                    end
                    yaml
                end

                def setup_from_conf(conf, yaml)
                    super
                    @rclone_path = conf.tool_path('rclone')
                    @src = yaml['src']
                    @filter = yaml['filter'] || []
                    @verbose = yaml.fetch('verbose', true)
                    @conf_path = conf.conf_path
                end

                def run
                    extra_args = []
                    if @bandwidth_limit
                        extra_args << '--bwlimit' << @bandwidth_limit.to_s
                    end
                    if @verbose
                        extra_args << "--verbose"
                    end

                    Tempfile.create "rclone-#{@name}", @conf_path.to_path, perm: 0600 do |io|
                        io.puts <<-EOCONF
[restic-service]
type = b2
account = #{@id}
key = #{@key}
endpoint =
EOCONF
                        io.flush
                        system(@rclone_path.to_path,
                            '--transfers', '16',
                            '--config', io.path,
                            '--delete-during',
                            *@filter.flat_map { |p| ['--filter', p] },
                            *extra_args,
                            'sync', @src, "restic-service:#{@bucket}/#{@path}", in: :close)
                    end
                end
            end
        end
    end
end
