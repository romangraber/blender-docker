# Blender on RunPod - bare minimum image
# Build with:
#   docker build --build-arg BLENDER_VERSION=4.4.3 --build-arg BLENDER_MAJOR=4.4 \
#                -t <user>/blender-runpod:4.4.3 .

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/opt/blender:${PATH}" \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all


# ---------------------------------------------------------------------------
# All apt work in a single layer, and on 24.04 a single `apt-get update`.
#
# NO PPA NEEDED HERE - this used to pull libstdc++6 from
# ppa:ubuntu-toolchain-r/test. Background, since it's easy to
# reintroduce by accident: some precompiled native Blender addons (e.g.
# SourceIO's pylib.abi3.so) are built against GCC 13 and need
# GLIBCXX_3.4.31. Ubuntu 22.04 topped out at GLIBCXX_3.4.30, so enabling
# them failed with:
#   ImportError: libstdc++.so.6: version `GLIBCXX_3.4.31' not found
# Noble ships the GCC 14 runtime (GLIBCXX_3.4.33), which already covers
# it. Dropping the PPA also drops software-properties-common, gnupg and
# the purge step that existed only to clean them up.
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        xz-utils \
        ca-certificates \
        openssh-server \
        rclone \
        python3-pip \
        libxi6 \
        libxxf86vm1 \
        libxfixes3 \
        libxrender1 \
        libxkbcommon0 \
        libxkbcommon-x11-0 \
        libsm6 \
        libgl1 \
        libglu1-mesa \
        libegl1 \
        libgles2 \
        libfontconfig1 \
        libboost-all-dev; \
    \
    # Build-time assertion, kept even though the PPA is gone: if a future
    # base image regresses the C++ runtime, fail here instead of shipping
    # an image that silently can't load GCC 13+ addons. grep -a reads the
    # .so directly - `strings` would need binutils, which isn't installed.
    grep -qa GLIBCXX_3.4.31 /usr/lib/x86_64-linux-gnu/libstdc++.so.6; \
    \
    # ws_server.py (shipped via manifest) streams render.log + GPU/CPU
    # samples over the websocket.
    #
    # --break-system-packages is required on 24.04: Python 3.12 enforces
    # PEP 668 and marks the system interpreter externally-managed, so pip
    # refuses to touch it without an override. Safe here - nothing else
    # in the image uses the system Python (Blender bundles its own), so
    # there is no dependency resolver to conflict with.
    pip3 install --no-cache-dir --break-system-packages websockets pillow; \
    python3 -c "import websockets; print('websockets', websockets.__version__)"; \
    python3 -c "from PIL import Image; print('pillow', Image.__version__)"; \
    \
    rm -rf /var/lib/apt/lists/*


# ---------------------------------------------------------------------------
# SSH for RunPod (key injected at runtime via the PUBLIC_KEY env var)
#
# Uses a drop-in rather than sed'ing sshd_config: `sed -i` exits 0 when
# its pattern doesn't match, so an upstream comment reword would silently
# leave root login disabled. sshd takes the FIRST value it sees for a
# keyword and sshd_config Includes this directory from its very first
# line, so these win over anything below. The grep asserts Include is
# actually present.
# ---------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd /root/.ssh /etc/ssh/sshd_config.d; \
    chmod 700 /root/.ssh; \
    grep -q 'Include /etc/ssh/sshd_config.d/\*.conf' /etc/ssh/sshd_config; \
    printf '%s\n' \
        'PermitRootLogin yes' \
        'PasswordAuthentication no' \
        'PubkeyAuthentication yes' \
        > /etc/ssh/sshd_config.d/00-runpod.conf


# ---------------------------------------------------------------------------
# cloudflared - exposes the local websocket as a *.trycloudflare.com URL.
# start.sh's `command -v cloudflared` check falls back to the 5s Upstash
# poll when this is absent, so older pods keep working.
#
# Tracks latest. To pin, swap the URL for:
#   https://github.com/cloudflare/cloudflared/releases/download/<tag>/cloudflared-linux-amd64
# ---------------------------------------------------------------------------
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/cloudflared \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64; \
    chmod +x /usr/local/bin/cloudflared; \
    cloudflared --version


# ---------------------------------------------------------------------------
# Blender. Last of the heavy layers and the only one keyed on the build
# args, so a version bump re-downloads this and nothing above it.
# ---------------------------------------------------------------------------
ARG BLENDER_VERSION=4.4.3
ARG BLENDER_MAJOR=4.4

RUN set -eux; \
    wget -qO /tmp/blender.tar.xz \
        "https://download.blender.org/release/Blender${BLENDER_MAJOR}/blender-${BLENDER_VERSION}-linux-x64.tar.xz"; \
    mkdir -p /opt/blender; \
    tar -xf /tmp/blender.tar.xz -C /opt/blender --strip-components 1; \
    rm /tmp/blender.tar.xz; \
    ln -s /opt/blender/blender /usr/local/bin/blender; \
    /opt/blender/blender --version


# --chmod needs BuildKit/buildx (which you're already using). Under the
# legacy builder, replace with a COPY + `RUN chmod +x /start.sh`.
COPY --chmod=755 start.sh /start.sh

WORKDIR /workspace
EXPOSE 22

CMD ["/start.sh"]
