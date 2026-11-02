#!/bin/bash

set -euo pipefail

DNF="dnf -y"

echo "::group:: Configure repositories"

# Drop Tailscale (shipped in base but unwanted here)
${DNF} remove tailscale

# COPR: LACT (GPU control daemon)
${DNF} copr enable ilyaz/LACT

# Docker CE
${DNF} config-manager addrepo --from-repofile https://download.docker.com/linux/fedora/docker-ce.repo

# Terra repos (gamescope / mesa / extras)
${DNF} install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release terra-gpg-keys
${DNF} install terra-release-mesa terra-release-extras

# Pin Terra above Fedora for mesa/gamescope, keep it from overriding selected packages
${DNF} config-manager setopt '*terra*.priority=1' \
    '*terra*.exclude=nerd-fonts scx-tools scx-scheds python3-protobuf zlib-devel uupd'
${DNF} config-manager setopt 'terra-mesa.enabled=false'
${DNF} config-manager setopt '*fedora*.exclude=steam mangohud'

# NetBird VPN
cat <<-EOF | tee /etc/yum.repos.d/netbird.repo
[NetBird]
name=NetBird
baseurl=https://pkgs.netbird.io/yum/
enabled=1
gpgcheck=0
gpgkey=https://pkgs.netbird.io/yum/repodata/repomd.xml.key
repo_gpgcheck=1
EOF

rpm-ostree install -y netbird netbird-ui

echo "::endgroup::"
echo "::group:: Install base packages"

# --setopt=install_weak_deps=False skips ~200 MiB of unwanted weak deps.
# Remove the flag if you discover you rely on any of them.
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
    qemu-char-spice
    qemu-audio-spice
    qemu-device-display-qxl
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-vga
    qemu-device-usb-redirect
    qemu-img
    qemu-system-x86-core
    qemu-ui-spice-core
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

${DNF} --setopt=install_weak_deps=False install "${FEDORA_PACKAGES[@]}"

echo "::endgroup::"
echo "::group:: Install gaming packages"

STEAM_PACKAGES=(
    terra-gamescope.x86_64
    terra-gamescope-libs.x86_64
    terra-gamescope-libs.i686
    umu-wrapper
    umu-launcher
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

${DNF} --enable-repo=terra-mesa --enable-repo=terra --enable-repo=terra-extras install "${STEAM_PACKAGES[@]}"
${DNF} --enable-repo=terra-mesa --enable-repo=terra --setopt=install_weak_deps=False install steam lutris

echo "::endgroup::"

# /opt is read-only in the final bootc image; relocate it to writable /var/opt.
# (bluefin may already ship this symlink — this is idempotent either way.)
rm -rf /opt
mkdir -p /var/opt
ln -s /var/opt /opt

echo "::group:: Install devsy / r2modman"
${DNF} install \
    https://github.com/ebkr/r2modmanPlus/releases/download/v3.2.20/r2modman-3.2.20.x86_64.rpm \
    https://github.com/devsy-org/devsy/releases/download/v1.24.0/Devsy_linux_x86_64.rpm
echo "::endgroup::"

echo "::group:: Enable services + cleanup"
systemctl enable lactd rasdaemon docker.socket podman.socket netbird
${DNF} copr disable ilyaz/LACT

# Update system flatpak list
cp /ctx/flatpak/*system*flatpak*.list /etc/ublue-os/
echo "::endgroup::"

echo 'Base build complete.'
