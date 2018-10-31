#! /bin/sh -ex

PROGRAM=restic-service

if test "x$1" = "x--systemd"; then
    systemd=1
fi

target=`mktemp -d`
cd $target
cat > Gemfile <<GEMFILE
source "https://rubygems.org"
gem '${PROGRAM}'
GEMFILE

bundler install --binstubs --without development --path vendor
for i in vendor/ruby/*; do
    gem_home_relative=$i
done
gem install bundler --no-document --no-user-install --install-dir $PWD/$gem_home_relative
for stub in bin/*; do
    sed -i "/usr.bin.env/a Gem.paths = { 'GEM_HOME' => '/opt/restic-service/$gem_home_relative' }" $stub
done

if test -d /opt/${PROGRAM}; then
    sudo rm -rf /opt/${PROGRAM}
fi
sudo cp -r . /opt/${PROGRAM}
sudo chmod go+rX /opt/${PROGRAM}

if test "x$systemd" = "x1" && test -d /lib/systemd/system; then
    target_gem=`bundler show ${PROGRAM}`
    sudo cp $target_gem/${PROGRAM}.service /lib/systemd/system
    ( sudo systemctl stop ${PROGRAM}.service
      sudo systemctl enable ${PROGRAM}.service
      sudo systemctl start ${PROGRAM}.service )
fi

rm -rf $target
