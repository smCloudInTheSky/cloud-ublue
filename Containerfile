# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files/
COPY flatpak /flatpak

FROM ghcr.io/ublue-os/bluefin-dx:stable@sha256:4cdb03b6c40a874e1602c783effbc8a6e5fd0655bd7c6cdc4bd2fcd935c0be66 as cloud-ublue

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
