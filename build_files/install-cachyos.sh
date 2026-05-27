#!/usr/bin/bash

set -eoux pipefail

echo "::group::Executing install-cachyos"
trap 'echo "::endgroup::"' EXIT

# create a shims to bypass kernel install triggering dracut/rpm-ostree
# seems to be minimal impact, but allows progress on build
pushd /usr/lib/kernel/install.d
mv 05-rpmostree.install 05-rpmostree.install.bak
mv 50-dracut.install 50-dracut.install.bak
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x  05-rpmostree.install 50-dracut.install
popd

# Remove Existing Kernel
for pkg in kernel kernel{-core,-modules,-modules-core,-modules-extra,-tools-libs,-tools}; do
    rpm --erase "${pkg}" --nodeps
done

dnf -y copr enable bieszczaders/kernel-cachyos
dnf -y copr enable bieszczaders/kernel-cachyos-addons
dnf -y install kernel-cachyos scx-scheds scx-tools scx-manager

# switch to cachyos default settings
dnf -y swap zram-generator-defaults cachyos-settings
dnf -y copr disable bieszczaders/kernel-cachyos
dnf -y copr disable bieszczaders/kernel-cachyos-addons

pushd /usr/lib/kernel/install.d
mv -f 05-rpmostree.install.bak 05-rpmostree.install
mv -f 50-dracut.install.bak 50-dracut.install
popd
