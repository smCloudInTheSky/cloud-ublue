#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging
dnf -y copr enable ilyaz/LACT
dnf -y copr enable praiskup/safeeyes
dnf -y install lact libvirt-devel mangohud pipx python3-safeeyes keepassxc firefox git-lfs clustershell vmaf-models vmaf libvmaf-devel
systemctl enable lactd
dnf -y copr disable ilyaz/LACT
dnf -y copr disable praiskup/safeeyes
dnf clean all
#### Example for enabling a System Unit File

# systemctl enable podman.socket

echo 'Complete.'
