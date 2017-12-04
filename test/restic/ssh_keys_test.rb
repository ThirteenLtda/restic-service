require "test_helper"

module Restic
    module Service
        describe SSHKeys do
            before do
                @ssh = SSHKeys.new
                @tempdir = Pathname.new(Dir.mktmpdir)
            end
            after do
                @tempdir.rmtree
            end

            it "creates the path and conf file if they don't exist" do
                path = @tempdir + "ssh" + "conf"
                @ssh.ssh_setup_config("test", "some_user", "192.168.0.1", "/path/to/key/file", ssh_config_path: path)

                result = path.read
                assert_equal <<-EXPECTED, result
# Added by restic-service
Host restic-service-host-test
  User some_user
  Hostname 192.168.0.1
  UserKnownHostsFile /path/to/key/file
                EXPECTED
            end

            it "adds the entry to an existing conf file" do
                path = @tempdir + "conf"
                path.open('w') do |io|
                    io.puts "Host another-host"
                    io.puts "  With some configuration"
                end
                @ssh.ssh_setup_config("test", "some_user", "192.168.0.1", "/path/to/key/file", ssh_config_path: path)

                result = path.read
                assert_equal <<-EXPECTED, result
Host another-host
  With some configuration

# Added by restic-service
Host restic-service-host-test
  User some_user
  Hostname 192.168.0.1
  UserKnownHostsFile /path/to/key/file
                EXPECTED
            end

            it "cleans up old entries first" do
                path = @tempdir + "conf"
                path.open('w') do |io|
                    io.puts <<-OLD_FILE
Host another-host
  With some configuration

# Added by restic-service
Host restic-service-host-test
  Hostname 192.168.0.1
  UserKnownHostsFile /path/to/key/file

Host another-host
  With some configuration
                OLD_FILE
                end
                @ssh.ssh_setup_config("test", "some_user", "192.168.0.1", "/path/to/key/file", ssh_config_path: path)

                result = path.read
                assert_equal <<-EXPECTED, result
Host another-host
  With some configuration

Host another-host
  With some configuration

# Added by restic-service
Host restic-service-host-test
  User some_user
  Hostname 192.168.0.1
  UserKnownHostsFile /path/to/key/file
                EXPECTED
            end
        end
    end
end

