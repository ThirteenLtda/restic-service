#! /bin/sh -ex

PROGRAM=restic-service

dev_path=$PWD

target=`mktemp -d`
cd $target
cat > Gemfile <<GEMFILE
source "https://rubygems.org"
gem '${PROGRAM}', path: "$dev_path"
GEMFILE

cat Gemfile

bundler install --standalone --binstubs
if test -d /opt/${PROGRAM}; then
    sudo rm -rf /opt/${PROGRAM}
fi
sudo cp -r . /opt/${PROGRAM}
sudo chmod go+rX /opt/${PROGRAM}

if test -d /lib/systemd/system; then
    target_gem=`bundler show ${PROGRAM}`
    sudo cp $target_gem/${PROGRAM}.service /lib/systemd/system
    ( sudo systemctl stop ${PROGRAM}.service
      sudo systemctl enable ${PROGRAM}.service
      sudo systemctl start ${PROGRAM}.service )
fi

rm -rf $target
