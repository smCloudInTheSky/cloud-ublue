#!/bin/bash

set -ouex pipefail

./tmp/build.sh

dnf -y copr enable abn/throttled
dnf -y copr enable sneexy/python-validity
dnf -y remove tuned tuned-ppd
dnf -y install --allowerasing igt-gpu-tools fprintd-clients  fprintd-clients-pam open-fprintd python3-validity tlp tlp-rdw throttled zcfan libva-intel-media-driver ffmpeg libva gstreamer1-plugin-vaapi mesa-va-drivers mesa-vulkan-drivers

dnf -y copr disable abn/throttled
dnf -y copr disable sneexy/python-validity
dnf clean all

echo "com.github.d4nj1.tlpui" >> /etc/ublue-os/system-flatpaks.list
systemctl enable tlp.service
systemctl enable zcfan.service
systemctl enable open-fprintd-resume.service open-fprintd-suspend.service open-fprintd.service python3-validity.service

echo 'Thinkpad build complete.'
