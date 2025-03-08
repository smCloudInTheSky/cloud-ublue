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

#### Example for enabling a System Unit File

# systemctl enable podman.socket

#### Customization

# Enabling lact on bluefin

IMAGE_INFO="/usr/share/ublue-os/image-info.json"
BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
    echo 'Installing LACT Libadwaita...'
    wget \
      $(curl -s https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest | \
      jq -r ".assets[] | select(.name | test(\"lact-libadwaita.*fedora-$(rpm -E %fedora)\")) | .browser_download_url") \
      -O lact.rpm
else
    echo 'Installing LACT...'
    wget \
      $(curl -s https://api.github.com/repos/ilya-zlobintsev/LACT/releases/latest | \
      jq -r ".assets[] | select(.name | test(\"lact-[0-9].*fedora-$(rpm -E %fedora)\")) | .browser_download_url") \
      -O lact.rpm
fi
dnf install -y lact.rpm
systemctl enable lactd
rm lact.rpm
echo 'Complete.'
