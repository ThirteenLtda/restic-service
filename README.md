# restic-service

A backup service using restic and rclone, meant to be run as a background
service.

## Usage

`restic-service` expects a YAML configuration file. By default, it is stored in
`/etc/restic-service/conf.yml`.

The template configuration file looks like this:

~~~ yaml
# The path to the underlying tools
tools:
  restic: /opt/restic
  rclone: /opt/rclone

# The targets. The only generic parts of a target definition
# are the name and type. The rest is target-specific
targets:
  - name: a_restic_sftp_target
    type: restic-sftp
~~~

## Remote host identification using SSH {#ssh_key_id}

Some target types recognize the remote host based on expected SSH keys.
Corresponding keys have to be stored locally in the `keys/` subfolder of
restic-service's configuration folder (i.e. /etc/restic-service/keys/ by
default). Targets that are recognized this way must have a file named
`${target_name}.keys`.

This file can be created using ssh's tools with

~~~
ssh-keyscan -H hostname > /etc/restic-service/keys/targetname.keys
~~~

## Target type: restic-sftp

The rest-sftp target backs files up using sftp on a remote target. The
target expects the SFTP authentication to be done [using SSH keys](#ssh_key_id).

The target takes the following arguments:

~~~ yaml
- name: name_of_target
  type: restic-sftp
  # The repo host. This is authenticated using SSH keys, so there must be a
  # corresponding keys/name_of_target.keys file in $CONF_DIR/keys
  host: host
  # The username that should be used to connect to the host
  username: the_user
  # The repo path on the host
  path: /
  # The repository password (encryption password from Restic)
  password: repo_password
  # Mandatory, list of paths to backup. Needs at least one
  includes:
  - list
  - of
  - paths
  - to
  - backup
  # Optional, list of excluded patterns
  excludes:
  - list/of/patterns
  - to/not/backup
  one_filesystem: false
  # Optional, the IO class. Defaults to 3 (Idle)
  io_class: 3
  # Optional, the IO priority. Unused for IO class 3
  io_priority: 0
  # Optional, the CPU priority. Higher gets less CPU
  cpu_priority: 19
~~~

## Target type: restic-b2

The rest-b2 target backs files up using sftp on a B2 bucket.

The target takes the following arguments:

~~~ yaml
- name: name_of_target
  type: restic-b2
  # The B2 bucket
  bucket: mybucket
  # The path within the bucket
  path: path
  # The B2 ID
  id:
  # The B2 Key
  key:
  # The repository password (encryption password from Restic)
  password: repo_password
  # Mandatory, list of paths to backup. Needs at least one
  includes:
  - list
  - of
  - paths
  - to
  - backup
  # Optional, list of excluded patterns
  excludes:
  - list/of/patterns
  - to/not/backup
  one_filesystem: false
  # Optional, the IO class. Defaults to 3 (Idle)
  io_class: 3
  # Optional, the IO priority. Unused for IO class 3
  io_priority: 0
  # Optional, the CPU priority. Higher gets less CPU
  cpu_priority: 19
~~~

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/ThirteenLtda/restic-service.

## License

The gem is available as open source under the terms of the [MIT
License](https://opensource.org/licenses/MIT).
