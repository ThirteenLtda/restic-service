require "test_helper"

module Restic
    module Service
        describe Conf do
            describe "target_class_from_type" do
                it "returns the target class from the target type" do
                    assert_same Targets::ResticB2, Conf.target_class_from_type("restic-b2")
                end
                it "raises InvalidConfigurationFile if the targe type does not match a registered type" do
                    e = assert_raises(Conf::InvalidConfigurationFile) do
                        Conf.target_class_from_type("does_not_exist")
                    end
                    assert_equal "target type does_not_exist does not exist, available targets: rclone-b2, restic-b2, restic-file, restic-sftp",
                        e.message
                end
            end

            describe ".parse_bandwidth_limit" do
                it "returns an integer as-is" do
                    assert_equal 100, Conf.parse_bandwidth_limit(100)
                end
                it "parses a plain integer represented as string" do
                    assert_equal 100, Conf.parse_bandwidth_limit("100")
                end
                it "scales a kilobyte value" do
                    assert_equal 3_000, Conf.parse_bandwidth_limit("3k")
                end
                it "scales a megabyte value" do
                    assert_equal 3_000_000, Conf.parse_bandwidth_limit("3M")
                end
                it "scales a gigabyte value" do
                    assert_equal 3_000_000_000, Conf.parse_bandwidth_limit("3G")
                end
                it "raises if the suffix is unknown" do
                    e = assert_raises(ArgumentError) do
                        Conf.parse_bandwidth_limit("3B")
                    end
                    assert_equal "cannot interpret '3B' as a valid bandwidth limit, give a plain number in bytes or use the k, M and G suffixes", e.message
                end
                it "accepts spaces between the value and the suffix" do
                    assert_equal 3_000_000_000, Conf.parse_bandwidth_limit("3 G")
                end
                it "does not take the case of the suffix into account" do
                    assert_equal 3_000_000_000, Conf.parse_bandwidth_limit("3g")
                end
            end

            describe "normalize_yaml" do
                it "does not modify the argument" do
                    Conf.normalize_yaml(h = Hash.new)
                    assert_equal Hash.new, h
                end
                it "sets default values if unset" do
                    assert_equal 3600, Conf.normalize_yaml(Hash.new)['period']
                end
                it "leaves provided values unchanged" do
                    assert_equal 1000, Conf.normalize_yaml('period' => 1000)['period']
                end
                it "validates that all targets have a name" do
                    e = assert_raises(Conf::InvalidConfigurationFile) do
                        Conf.normalize_yaml('targets' => [Hash.new])
                    end
                    assert_equal "missing 'name' field in target",
                        e.message
                end
                it "validates that all targets have a type" do
                    e = assert_raises(Conf::InvalidConfigurationFile) do
                        Conf.normalize_yaml('targets' => ['name' => 'test'])
                    end
                    assert_equal "missing 'type' field in target",
                        e.message
                end
                it "validates that the target type exists" do
                    e = assert_raises(Conf::InvalidConfigurationFile) do
                        Conf.normalize_yaml('targets' => ['name' => 'test', 'type' => 'does_not_exist'])
                    end
                    assert_equal "target type does_not_exist does not exist, available targets: rclone-b2, restic-b2, restic-file, restic-sftp",
                        e.message
                end
                it "validates that targets do not have duplicate names" do
                    target = {'name' => 'test', 'type' => 'restic-b2'}
                    flexmock(Targets::ResticB2).should_receive(:normalize_yaml).
                        and_return(target)
                    e = assert_raises(Conf::InvalidConfigurationFile) do
                        Conf.normalize_yaml('targets' => [target, target])
                    end
                    assert_equal "duplicate target name 'test'",
                        e.message
                end
                it "lets the target class normalize the type further" do
                    flexmock(Conf).should_receive(:target_class_from_type).
                        with('test').and_return(target_mock = flexmock)
                    target_mock.should_receive(:normalize_yaml).and_return(normalized = flexmock)
                    assert_equal [normalized], Conf.normalize_yaml('targets' => ['name' => 'test', 'type' => 'test'])['targets']
                end
            end

            describe "#find_in_path" do
                before do
                    @actual_path = ENV['PATH'].dup
                    @tempdir = Pathname.new(Dir.mktmpdir)
                    ENV['PATH'] = ['/usr/bin', '/usr', @tempdir].
                        join(File::PATH_SEPARATOR)
                    @conf = Conf.new(@tempdir)
                end
                after do
                    ENV['PATH'] = @actual_path
                    @tempdir.rmtree
                end

                it "returns the first match in the PATH" do
                    (@tempdir + "restic-service-test").open('w') { }
                    assert_equal (@tempdir + "restic-service-test"),
                        @conf.find_in_path('restic-service-test')
                end

                it "nil if nothing matches" do
                    assert_nil @conf.find_in_path('restic-service-test')
                end
            end

            describe "#target_by_name" do
                before do
                    @conf = Conf.new(Pathname.new("/"))
                end
                it "returns a registered target" do
                    @conf.register_target(target = flexmock(name: 'test'))
                    assert_same target, @conf.target_by_name('test')
                end
                it "raises NoSuchTarget if it does not exist" do
                    e = assert_raises(Conf::NoSuchTarget) do
                        @conf.target_by_name('test')
                    end
                    assert_equal "no target named 'test'", e.message
                end
            end

            describe "#load_from_yaml" do
                before do
                    @actual_path = ENV['PATH'].dup
                    @tempdir = Pathname.new(Dir.mktmpdir)
                    ENV['PATH'] = ['/usr/bin', '/usr', @tempdir].
                        join(File::PATH_SEPARATOR)
                    @conf = Conf.new(@tempdir)
                    @tool_path = (@tempdir + "restic-test")
                    flexmock(STDERR).should_receive(:puts).with("cannot find path to rclone")
                    flexmock(STDERR).should_receive(:puts).with("cannot find path to restic")
                end
                after do
                    ENV['PATH'] = @actual_path
                    @tempdir.rmtree
                end

                def normalize_and_load_from_yaml(yaml)
                    @conf.load_from_yaml(Conf.normalize_yaml(yaml))
                end

                it "sets the period from the hash" do
                    normalize_and_load_from_yaml('period' => 10)
                    assert_equal 10, @conf.period
                end
                it "sets the bandwidth limit to nil if the hash does not set it" do
                    normalize_and_load_from_yaml(Hash.new)
                    assert_nil @conf.bandwidth_limit
                end
                it "parses the bandwidth limit if the hash has a value" do
                    flexmock(Conf).should_receive(:parse_bandwidth_limit).with('test').and_return(20)
                    normalize_and_load_from_yaml('bandwidth_limit' => 'test')
                    assert_equal 20, @conf.bandwidth_limit
                end

                it "sets the targets from the hash" do
                    target_yaml = {'name' => 'test-target', 'type' => 'test', 'more_data' => 'data'}
                    flexmock(Conf).should_receive(:target_class_from_type).
                        with('test').and_return(target_mock = flexmock)
                    target_mock.should_receive(:new).with('test-target').and_return(target_mock)
                    target_mock.should_receive(:name).and_return('normalized-test-target')
                    target_mock.should_receive(:normalize_yaml).and_return(target_yaml)
                    target_mock.should_receive(:setup_from_conf).with(@conf, target_yaml)
                    normalize_and_load_from_yaml('targets' => [target_yaml])
                    assert_equal target_mock, @conf.target_by_name('normalized-test-target')
                end

                it "sets up a tool directly if given as full path" do
                    @tool_path.open('w') { }
                    normalize_and_load_from_yaml('tools' => Hash['restic' => @tool_path.to_s])
                    assert_equal @tool_path, @conf.tool_path('restic')
                end
                it "does not set up a tool from a full path that does not exist, and warns abou it" do
                    flexmock(STDERR).should_receive(:puts).with("cannot find path to restic")
                    normalize_and_load_from_yaml('tools' => Hash['restic' => @tool_path.to_s])
                    assert_raises(ArgumentError) { @conf.tool_path('restic') }
                end
                it "resolves a tool if given as relative path" do
                    @tool_path.open('w') { }
                    normalize_and_load_from_yaml('tools' => Hash['restic' => 'restic-test'])
                    assert_equal @tool_path, @conf.tool_path('restic')
                end
                it "does not set up a tool from a relative path that does not exist, and warns abou it" do
                    flexmock(STDERR).should_receive(:puts).with("cannot find path to restic")
                    normalize_and_load_from_yaml('tools' => Hash['restic' => 'restic-test'])
                    assert_raises(ArgumentError) { @conf.tool_path('restic') }
                end
            end
        end
    end
end
