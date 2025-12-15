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
dnf -y install lact libvirt-devel mangohud pipx keepassxc firefox git-lfs clustershell vmaf-models vmaf libvmaf-devel s-tui rasdaemon acpica-tools edid-decode telnet libreswan edk2-ovmf

#### Example of preparation for installing a package that requires a symlinked directory

# /opt is symlinked to /var/opt
rm -f /opt
ln -sr /opt /var/opt
# for packages that require it to be writeable do the following:
# install package (dnf5 -y install .....)
dnf install -y https://github.com/ebkr/r2modmanPlus/releases/download/v3.2.3/r2modman-3.2.3.x86_64.rpm

cat <<-EOF | tee /etc/yum.repos.d/netbird.repo
[NetBird]
name=NetBird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=0
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF

rpm-ostree -y install netbird netbird-ui

systemctl enable netbird

# move files installed to /opt to /usr/share/factory so they will be in the final image
# Enable /var/opt to be recreate by systemd tmpfiles feature
#
# log command to check things
# ls -lah /var/opt/

systemctl enable lactd
systemctl enable rasdaemon
# Zoom install because zoom is broken
dnf -y copr disable ilyaz/LACT
dnf -y copr disable praiskup/safeeyes
dnf clean all
#### Example for enabling a System Unit File


## update system flatpak List
cp /ctx/flatpak/*system*flatpak*.list /etc/ublue-os/

# systemctl enable podman.socket

echo 'Base build complete.'
