FROM ghcr.io/ublue-os/bluefin-dx:stable as cloud-ublue

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:stable
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
#
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

COPY build.sh /tmp/build.sh
COPY flatpak/system-flatpaks.list /tmp/system-flatpaks.list
COPY flatpak/system-flatpaks-dx.list /tmp/system-flatpaks-dx.list
COPY cosign.pub /etc/pki/containers/cloud.pub

RUN mkdir -p /var/lib/alternatives && \
    /tmp/build.sh && \
    ostree container commit

RUN bootc container lint

FROM ghcr.io/ublue-os/bluefin-dx:stable as thinkpad-ublue

COPY build.sh /tmp/build.sh
COPY build_thinkpad.sh /tmp/build_thinkpad.sh
COPY cosign.pub /etc/pki/containers/cloud.pub
COPY flatpak/system-flatpaks.list /tmp/system-flatpaks.list
COPY flatpak/system-flatpaks-dx.list /tmp/system-flatpaks-dx.list
RUN mkdir -p /var/lib/alternatives && \
    /tmp/build_thinkpad.sh && \
    ostree container commit

RUN bootc container lint
