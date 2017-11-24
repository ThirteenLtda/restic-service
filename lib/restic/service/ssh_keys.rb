module Restic
    module Service
        # Interface to the functionality of querying and verifying host keys
        class SSHKeys
            class SSHFailed < RuntimeError; end
            class NoLocalKey < RuntimeError; end
            class ValidationFailed < RuntimeError; end

            PublicKey = Struct.new :type, :hash do
                def ==(other)
                    other.type == type &&
                        other.hash == hash
                end
            end
            
            # Load a set of SSH keys from a file
            #
            # @return [Array<PublicKey>]
            def self.load_keys_from_file(path)
                load_keys_from_string(path.read)
            end

            # Load a set of SSH keys from a string
            #
            # @return [Array<PublicKey>]
            def self.load_keys_from_string(string)
                string.each_line.map do |line|
                    _, key_type, *rest = line.chomp.split(" ")
                    PublicKey.new(key_type, rest.join(" "))
                end
            end

            # Query the list of keys for this host
            #
            # @param [#host]
            def query_keys(host)
                self.class.load_keys_from_string(ssh_keyscan_host(host))
            end

            # Query the keys from a host and returns them as a SSH key string
            def ssh_keyscan_host(host)
                ssh_key_run('ssh-keyscan', '-H', host)
            end

            # Run a ssh subprocess and returns its standard output
            #
            # @raise [SSHFailed] if the subcommand fails
            def ssh_key_run(*args)
                out_pipe_r, out_pipe_w = IO.pipe
                err_pipe_r, err_pipe_w = IO.pipe
                pid = spawn *args, in: :close, err: err_pipe_w, out: out_pipe_w
                out_pipe_w.close
                err_pipe_w.close
                _, status = Process.waitpid2 pid

                out = out_pipe_r.read
                err_pipe_r.readlines.each do |line|
                    if line !~ /^#/
                        STDERR.puts line
                    end
                end

                if !status.success?
t                    raise SSHFailed, "failed to run #{args}"
                end
                out
            ensure
                out_pipe_r.close
                err_pipe_r.close
            end
        end
    end
end

