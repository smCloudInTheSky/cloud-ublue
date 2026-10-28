#!/bin/bash

set -oue pipefail

DNF_CMD="dnf -y"
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

echo "::group:: Install base packages"
${DNF_CMD} remove tailscale
${DNF_CMD} copr enable ilyaz/LACT
${DNF_CMD} config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo
${DNF_CMD} install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
${DNF_CMD} install terra-release-mesa terra-release-extras
${DNF_CMD} config-manager setopt "*terra*".priority=1 "*terra*".exclude="nerd-fonts scx-tools scx-scheds python3-protobuf zlib-devel uupd"
${DNF_CMD} config-manager setopt "terra-mesa".enabled=false
${DNF_CMD} config-manager setopt "*fedora*".exclude="steam mangohud"
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
    libxcb-devel
    libxkbcommon-devel
    libxkbcommon-x11-devel
    lxc
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
    winetricks
    ydotool
)

STEAM_PACKAGES=(
    terra-gamescope.x86_64
    terra-gamescope-libs.x86_64
    terra-gamescope-libs.i686
    umu-wrapper
    umu-launcher
    dbus-x11
    xrandr
    evtest
    xdg-user-dirs
    xdg-terminal-exec
    gobject-introspection
    libFAudio.x86_64
    libFAudio.i686
    vkBasalt.x86_64
    vkBasalt.i686
    terra-mangohud.x86_64
    terra-mangohud.i686
    obs-studio-plugin-vkcapture-hook-libs.x86_64
    obs-studio-plugin-vkcapture-hook-libs.i686
    openxr
    openxr-libs
)

${DNF_CMD} install "${FEDORA_PACKAGES[@]}"
# Install steam packages
${DNF_CMD} --enable-repo=terra-mesa --enable-repo=terra --enable-repo=terra-extras install "${STEAM_PACKAGES[@]}"
${DNF_CMD} --enable-repo=terra-mesa --enable-repo=terra --setopt=install_weak_deps=False install steam lutris
#### Example of preparation for installing a package that requires a symlinked directory

echo "::endgroup::"
# /opt is symlinked to /var/opt
rm -f /opt
ln -sr /opt /var/opt
# for packages that require it to be writeable do the following:
# install package (dnf5 -y install .....)
echo "::group:: Install devsy/r2modman"
${DNF_CMD} install https://github.com/ebkr/r2modmanPlus/releases/download/v3.2.20/r2modman-3.2.20.x86_64.rpm
${DNF_CMD} install https://github.com/devsy-org/devsy/releases/download/v1.24.0/Devsy_linux_x86_64.rpm


echo "::endgroup::"
echo "::group:: Install Netbird"
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

echo "::endgroup::"
echo "::group:: Enable services + cleanup"
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
${DNF_CMD} copr disable ilyaz/LACT
dnf clean all
#### Example for enabling a System Unit File

## update system flatpak List
cp /ctx/flatpak/*system*flatpak*.list /etc/ublue-os/

systemctl enable podman.socket
echo "::endgroup::"

echo 'Base build complete.'
