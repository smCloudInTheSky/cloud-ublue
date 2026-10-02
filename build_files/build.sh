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
dnf -y config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
# install extra packages

FEDORA_PACKAGES=(
    android-tools
    bcc
    bpftop
    bpftrace
    cascadia-code-fonts
    clustershell
    containerd.io
    dbus-x11
    docker-buildx-plugin
    docker-ce
    docker-ce-cli
    docker-compose-plugin
    edk2-ovmf
    firefox
    flatpak-builder
    genisoimage
    git-lfs
    git-subtree
    git-svn
    incus
    incus-agent
    iotop
    keepassxc
    lact
    libvirt
    libvirt-client
    libvirt-daemon
    libvirt-devel
    libvirt-nss
    libvmaf-devel
    lxc
    mangohud
    nicstat
    numactl
    osbuild-selinux
    p7zip
    p7zip-plugins
    pipx
    podman-compose
    podman-machine
    podman-tui
    qemu
    qemu-char-spice
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-user-binfmt
    qemu-user-static
    rasdaemon
    sysprof
    tiptop
    trace-cmd
    udica
    util-linux-script
    virt-manager
    virt-v2v
    virt-viewer
    vmaf
    vmaf-models
    wtype
    ydotool
)
dnf -y install "${FEDORA_PACKAGES[@]}"
#### Example of preparation for installing a package that requires a symlinked directory

# /opt is symlinked to /var/opt
rm -f /opt
ln -sr /opt /var/opt
# for packages that require it to be writeable do the following:
# install package (dnf5 -y install .....)
dnf install -y https://github.com/ebkr/r2modmanPlus/releases/download/v3.2.20/r2modman-3.2.20.x86_64.rpm
dnf install -y https://github.com/devsy-org/devsy/releases/download/v1.19.0/Devsy_linux_x86_64.rpm


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
systemctl enable docker.socket
systemctl enable podman.socket
# Zoom install because zoom is broken
dnf -y copr disable ilyaz/LACT
dnf clean all
#### Example for enabling a System Unit File

## update system flatpak List
cp /ctx/flatpak/*system*flatpak*.list /etc/ublue-os/

ls -lah /usr/lib/modules/*/
# systemctl enable podman.socket

echo 'Base build complete.'
