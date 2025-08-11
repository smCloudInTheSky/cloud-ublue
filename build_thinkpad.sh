#!/bin/bash

set -ouex pipefail

./tmp/build.sh

dnf -y copr enable abn/throttled
dnf -y copr enable sneexy/python-validity
dnf -y remove tuned tuned-ppd
dnf -y group install sound-and-video
dnf -y install --allowerasing gstreamer1-plugin-vaapi libheif igt-gpu-tools fprintd-clients fprintd-clients-pam open-fprintd python3-validity tlp tlp-rdw throttled zcfan alsa-firmware ffmpegthumbnailer heif-pixbuf-loader libcamera-gstreamer libcamera-tools libva-utils pipewire-plugin-vulkan vulkan-headers
dnf -y swap --from-repo=fedora-multimedia ffmpeg-free ffmpeg
dnf -y swap --from-repo=fedora-multimedia libavcodec-free libavcodec
dnf -y swap --from-repo=fedora-multimedia libfdk-aac-free libfdk-aac
dnf -y swap --from-repo=fedora-multimedia intel-media-driver libva-intel-media-driver
dnf -y swap --from-repo=fedora-multimedia libva libva
dnf -y swap --from-repo=fedora-multimedia mesa-dri-drivers mesa-dri-drivers
dnf -y swap --from-repo=fedora-multimedia mesa-filesystem mesa-filesystem
dnf -y swap --from-repo=fedora-multimedia mesa-libEGL mesa-libEGL
dnf -y swap --from-repo=fedora-multimedia mesa-libGL mesa-libGL
dnf -y swap --from-repo=fedora-multimedia mesa-libgbm mesa-libgbm
dnf -y swap --from-repo=fedora-multimedia mesa-va-drivers mesa-va-drivers
dnf -y swap --from-repo=fedora-multimedia mesa-vulkan-drivers mesa-vulkan-drivers

dnf -y copr disable abn/throttled
dnf -y copr disable sneexy/python-validity
dnf clean all

echo -e "\n com.github.d4nj1.tlpui" >> /etc/ublue-os/system-flatpaks.list
systemctl enable tlp.service
systemctl enable zcfan.service
systemctl enable open-fprintd-resume.service open-fprintd-suspend.service open-fprintd.service python3-validity.service

echo 'Thinkpad build complete.'
