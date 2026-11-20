#!/bin/bash

set -oue pipefail

echo "::group:: Configure thinkpad tooling"
dnf -y copr enable sneexy/python-validity
dnf -y remove tuned tuned-ppd
dnf -y install https://github.com/erpalma/throttled/releases/download/v0.13/throttled-0.13-1.noarch.rpm
dnf -y install --allowerasing igt-gpu-tools fprintd-clients fprintd-clients-pam open-fprintd python3-validity tlp tlp-rdw zcfan

dnf -y copr disable sneexy/python-validity
dnf clean all

echo -e "\ncom.github.d4nj1.tlpui" >> /etc/ublue-os/system-flatpaks.list
systemctl enable tlp.service
systemctl enable zcfan.service
systemctl enable throttled.service
systemctl enable open-fprintd-resume.service open-fprintd-suspend.service open-fprintd.service python3-validity.service
systemctl mask systemd-rfkill.service
systemctl mask systemd-rfkill.socket

echo "::endgroup::"
echo "::group:: Enable services + cleanup"
echo 'Thinkpad build complete.'
