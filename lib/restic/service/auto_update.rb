require 'net/https'

module Restic
    module Service
        class AutoUpdate
            class FailedUpdate < RuntimeError
            end

            RESTIC_RELEASE_VERSION = "0.8.3"

            def self.restic_release_url(platform)
                "https://github.com/restic/restic/releases/download/v#{RESTIC_RELEASE_VERSION}/restic_#{RESTIC_RELEASE_VERSION}_#{platform}.bz2"
            end


            def initialize(binary_path)
                @root = File.dirname(File.dirname(binary_path))
                unless File.file?(File.join(@root, "Gemfile"))
                    raise FailedUpdate, "cannot guess installation path (tried #{@root})"
                end

                @gem_home = ENV['GEM_HOME']
            end

            def patch_binstubs
                bindir = File.join(@root, 'bin')
                Dir.new(bindir).each do |entry|
                    entry = File.join(bindir, entry)
                    if File.file?(entry)
                        patched_contents = File.readlines(entry)
                        patched_contents.insert(1, "ENV['GEM_HOME'] = '#{@gem_home}'\n")
                        File.open(entry, 'w') do |io|
                            io.write patched_contents.join("")
                        end
                    end
                end
            end

            def current_gem_version(gem_name)
                gemfile_lock = File.join(@root, "Gemfile.lock")
                File.readlines(gemfile_lock).each do |line|
                    match = /^\s+#{gem_name} \((.*)\)$/.match(line)
                    return match[1] if match
                end
                raise FailedUpdate, "cannot find the version line for #{gem_name} in #{gemfile_lock}"
            end

            def update_restic_service
                current_version = current_gem_version "restic-service"
                reader, writer = IO.pipe
                if !system("bundle", "update", out: writer, err: writer)
                    writer.close
                    puts reader.read(1024)
                    raise FailedUpdate, "failed to run bundle update"
                end
                patch_binstubs
                new_version = current_gem_version "restic-service"
                [current_version, new_version]
            ensure
                writer.close if writer && !writer.closed?
                reader.close if reader && !reader.closed?
            end

            def update_restic(platform, target_path)
                release_url = self.class.restic_release_url(platform)

                release_binary = nil
                while !release_binary
                    response = Net::HTTP.get_response(URI(release_url))
                    case response
                    when Net::HTTPSuccess
                        release_binary = response.body
                    when Net::HTTPRedirection
                        release_url = response['location']
                    else
                        raise FailedUpdate, "failed to fetch restic at #{release_url}: #{response}"
                    end
                end

                tmpdir = Dir.mktmpdir
                restic_path = File.join(tmpdir, "restic")
                File.open("#{restic_path}.bz2", 'w') do |io|
                    io.write release_binary
                end

                if !system("bzip2", "-d", "#{restic_path}.bz2")
                    raise FailedUpdate, "failed to uncompress the restic release file"
                end

                if File.file?(target_path)
                    current = File.read(target_path)
                    new     = File.read(restic_path)
                    return if current == new
                end

                FileUtils.mv restic_path, target_path
                FileUtils.chmod 0755, target_path
                true

            ensure
                FileUtils.rm_rf tmpdir if tmpdir
            end
        end
    end
end

