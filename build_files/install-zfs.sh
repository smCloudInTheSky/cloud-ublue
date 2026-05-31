#!/usr/bin/bash

set -eoux pipefail

echo "::group::Executing install-zfs"
trap 'echo "::endgroup::"' EXIT

# install official legacy fedora repo
dnf install -y https://zfsonlinux.org/fedora/zfs-release-3-1$(rpm --eval "%{dist}").noarch.rpm
echo "zfs" >/usr/lib/modules-load.d/zfs.conf

sudo dnf -y install zfs
