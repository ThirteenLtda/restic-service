require 'thor'
require 'restic/service'

module Restic
    module Service
        DEFAULT_CONF = "/etc/restic-service"

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
                    Conf.load(conf_file_path)
                end

                def each_selected_and_available_target(conf, *targets)
                    has_target = false
                    conf.each_target do |target|
                        has_target = true
                        if !targets.empty? && !targets.include?(target.name)
                            next
                        elsif !target.available?
                            puts "#{target.name} is not available"
                            next
                        end

                        yield(target)
                    end

                    if !has_target
                        STDERR.puts "WARNING: no targets in #{options[:conf]}"
                    end
                end

                def run_sync(conf, *targets)
                    each_selected_and_available_target(conf, *targets) do |target|
                        puts
                        puts "-----"
                        puts "#{Time.now} - Synchronizing #{target.name}"
                        target.run
                    end
                end

                def run_forget(conf, *targets)
                    each_selected_and_available_target(conf, *targets) do |target|
                        unless target.respond_to?(:forget)
                            puts "#{target.name} does not supports forget"
                            next
                        end

                        puts
                        puts "-----"
                        puts "#{Time.now} - Running forget pass on #{target.name}"
                        target.forget
                    end
                end

                def auto_update_tool(conf, updater, name, version)
                    begin
                        path = conf.tool_path(name, only_if_present: false)
                    rescue ArgumentError
                        puts "cannot auto-update #{name}, provide an explicit path in the 'tools' section of the configuration first"
                        return
                    end

                    puts "attempting to auto-update #{name}"
                    if updater.send("update_#{name}", conf.send("#{name}_platform"), path)
                        puts "updated #{name} to version #{version}"
                    else
                        puts "restic was already up-to-date"
                    end
                end
            end

            desc 'whereami', 'finds the available backup targets'
            def whereami
                STDOUT.sync = true
                conf = load_conf
                conf.each_target do |target|
                    print "#{target.name}: "
                    puts(target.available? ? 'yes' : 'no')
                end
            end

            desc 'install-restic PATH PLATFORM', 'install restic'
            def install_restic(path, platform)
                updater = AutoUpdate.new($0)
                updater.update_restic(platform, path)
            end

            desc 'auto-update', 'perform auto-updating as configured in the configuration file'
            def auto_update
                conf = load_conf
                STDOUT.sync = true

                updater = AutoUpdate.new($0)
                if conf.auto_update_restic_service?
                    puts "attempting to auto-update restic-service"
                    old_version, new_version = updater.update_restic_service
                    if old_version != new_version
                        puts "updated restic-service from #{old_version} to #{new_version}, restarting"
                        exec "bundle", "exec", Gem.ruby, $0, "auto-update"
                    else
                        puts "restic-service was already up-to-date: #{new_version}"
                    end
                else
                    puts "updating restic-service disabled in configuration"
                end

                if conf.auto_update_restic?
                    auto_update_tool(conf, updater, 'restic', AutoUpdate::RESTIC_RELEASE_VERSION)
                else
                    puts "updating restic disabled in configuration"
                end

                if conf.auto_update_rclone?
                    auto_update_tool(conf, updater, 'rclone', AutoUpdate::RCLONE_RELEASE_VERSION)
                else
                    puts "updating rclone disabled in configuration"
                end
            end

            desc 'sync', 'synchronize all (some) targets'
            def sync(*targets)
                STDOUT.sync = true
                conf = load_conf
                run_sync(conf, *targets)
            end

            desc 'forget', 'delete historical data'
            def forget(*targets)
                STDOUT.sync = true
                conf = load_conf
                run_forget(conf, *targets)
            end

            desc 'auto', 'periodically runs the backups, pass target names to restrict to these'
            def auto(*targets)
                STDOUT.sync = true
                conf = load_conf
                loop do
                    puts "#{Time.now} Starting automatic synchronization pass"
                    puts ""

                    run_sync(conf, *targets)
                    run_forget(conf, *targets)

                    puts ""
                    puts "#{Time.now} Finished automatic synchronization pass"

                    sleep conf.period
                end
            end
        end
    end
end
