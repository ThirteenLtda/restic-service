module Restic
    module Service
        module Targets
            class Rsync < Base
                include SSHTarget

                def self.normalize_yaml(yaml)
                    yaml = super
                    if !yaml['host']
                        raise Conf::InvalidConfigurationFile, "no host given"
                    elsif !yaml['source']
                        raise Conf::InvalidConfigurationFile, "no source given"
                    elsif !yaml['target']
                        raise Conf::InvalidConfigurationFile, "no target given"
                    end
                    yaml
                end

                def setup_from_conf(conf, yaml)
                    super
                    @source = yaml.fetch('source')
                    @target = yaml.fetch('target')
                    @one_file_system = yaml.fetch('one_file_system', false)
                    @filters = yaml.fetch('filters', [])
                end

                def run(*args, **options)
                    extra_args = []
                    if @one_file_system
                        extra_args << "--one-file-system"
                    end
                    if @bandwidth_limit
                        limit_KiB = @bandwidth_limit / 1000 
                        extra_args << "--bwlimit=#{limit_KiB}"
                    end

                    home = ENV['HOME'] || '/root'

                    with_ssh_config do |ssh_config_name|
                        system(Hash['HOME' => home], *nice_commands,
                               'rsync', '-a', '--delete-during', '--delete-excluded',
                               *@filters.map { |arg| "--filter=#{arg}" },
                               *extra_args, @source, "#{ssh_config_name}:#{@target}")
                    end
                end
            end
        end
    end
end

