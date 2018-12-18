module Restic
    module Service
        module Targets
            # A target that backs up to a SFTP target using Restic
            #
            # See README.md for the YAML configuration file format
            class ResticB2 < Restic
                include B2

                def self.normalize_yaml(yaml)
                    yaml = B2.normalize_yaml(yaml)
                    super(yaml)
                end

                def run
                    run_backup(Hash['B2_ACCOUNT_ID' => @id, 'B2_ACCOUNT_KEY' => @key],
                          '-r', "b2:#{@bucket}:#{@path}", 'backup')
                end

                def forget
                    run_forget(Hash['B2_ACCOUNT_ID' => @id, 'B2_ACCOUNT_KEY' => @key],
                          '-r', "b2:#{@bucket}:#{@path}", 'forget')
                end

                def restic(*args)
                    run_restic(Hash['B2_ACCOUNT_ID' => @id, 'B2_ACCOUNT_KEY' => @key],
                          '-r', "b2:#{@bucket}:#{@path}", *args)
                end
            end
        end
    end
end
