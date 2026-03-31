# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files/
COPY flatpak /flatpak

FROM ghcr.io/ublue-os/bluefin-dx:stable@sha256:7e0efc74bbd431a9c1b2f75cb13c22ff96f5c535ef695c96d535587a943073d6 as cloud-ublue

COPY cosign.pub /etc/pki/containers/cloud.pub

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/lib/alternatives && \
    /ctx/build_files/build.sh && \
    ostree container commit

RUN bootc container lint

FROM cloud-ublue as thinkpad-ublue

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build_thinkpad.sh && \
    ostree container commit

RUN bootc container lint
