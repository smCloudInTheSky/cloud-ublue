# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /build_files/
COPY system_files /files

FROM ghcr.io/ublue-os/bluefin:stable@sha256:5cfb4b4bd339eaa77f36fc948efaa32cf336d368e0a447a4f1053c06808927bb as cloud-ublue

# Static system configuration (gamemode.ini, polkit rules, flatpak lists).
# Keep defaults in /etc: on install/upgrade bootc turns the image's /etc into
# the deployment's /usr/etc defaults and 3-way merges them into the writable
# /etc. Never copy files to /usr/etc here -- it is generated client-side and
# `bootc container lint` fails the etc-usretc check when /usr/etc exists.
# Copied before the build scripts run so build.sh and build_thinkpad.sh
# can rely on these files already being present under /etc.
COPY --chown=0:0 --from=ctx /files/ /

COPY cosign.pub /etc/pki/containers/cloud.pub

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    mkdir -p /var/lib/alternatives && \
    /ctx/build_files/build.sh && \
    ostree container commit

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/build_files/bootc-postprocess.sh

RUN bootc container lint --fatal-warnings --no-truncate

FROM cloud-ublue as thinkpad-ublue

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build_thinkpad.sh && \
    ostree container commit

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/build_files/bootc-postprocess.sh

RUN bootc container lint --fatal-warnings --no-truncate
