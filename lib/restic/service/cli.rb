require 'thor'
require 'restic/service'

module Restic
    module Service
        DEFAULT_CONF = "/etc/restic-service/conf.yml"

        class CLI < Thor
            class_option :conf, desc: "path to the configuration file (#{DEFAULT_CONF})",
                type: :string, default: DEFAULT_CONF

            no_commands do
                def conf_dir_path
                    @conf_dir_path ||= Pathname.new(options[:conf])
                end

                def conf_file_path
                    @conf_file_path ||= (conf_dir_path + "conf.yml")
                end

                def conf_keys_path
                    @conf_keys_path ||= (conf_dir_path + "keys")
                end

                def load_conf
                    conf = Conf.load(conf_file_path)
                    conf.load_keys_from_disk(conf_keys_path)
                    conf
                end
            end

            desc 'whereami', 'finds the available backup servers'
            def whereami
                ssh = SSHKeys.new
                STDOUT.sync = true
                conf = load_conf
                conf.each_target do |target|
                    print "#{target.name}: "
                    actual_keys = ssh.query_keys(target.host)
                    if target.valid?(actual_keys)
                        puts "yes"
                    else
                        puts "no"
                    end
                end
            end

            desc 'add-target NAME HOST', 'adds a target to the configuration'
            def add_target(name, host)
                ssh = SSHKeys.new
                keys = ssh.ssh_keyscan_host(host)
                conf_keys_path.mkpath
                (conf_keys_path + "#{name}.keys").open('w') do |io|
                    io.write keys
                end

                if conf_file_path.file?
                    yaml = YAML.load(conf_file_path.read)
                else yaml = Hash.new
                end
                yaml['targets'] ||= Array.new
                yaml['targets'].delete_if { |t| t['name'] == name }
                yaml['targets'] << Hash['name' => name, 'host' => host]
                conf_file_path.open('w') do |io|
                    YAML.dump(yaml, io)
                end
            end

            desc 'auto', 'periodically runs the backups'
            def auto
                ssh = SSHKeys.new
                conf = load_conf
                STDOUT.sync = true
                loop do
                    conf.each_target do |target|
                        puts target.name
                        actual_keys = ssh.query_keys(target.host)
                        if !target.valid?(actual_keys)
                            puts "#{target.name} is not available"
                            next
                        end

                        puts "Synchronizing #{target.name}"
                        target.run(conf.restic_path)
                    end
                    sleep conf.period
                end
            end
        end
    end
end

