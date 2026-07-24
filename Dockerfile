# Blender on RunPod - bare minimum image
# Build with:
#   docker build --build-arg BLENDER_VERSION=4.4.3 --build-arg BLENDER_MAJOR=4.4 \
#                -t <user>/blender-runpod:4.4.3 .

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/opt/blender:${PATH}" \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=all


# ---------------------------------------------------------------------------
# All apt work in a single layer.
#
# Two `apt-get update` calls are the minimum here and both are load-bearing:
#   1. the base image ships an empty package index, so nothing installs
#      without it;
#   2. `add-apt-repository` only writes a sources.list entry + key - the
#      PPA's index still has to be fetched before libstdc++6 resolves to
#      the newer build.
#
# WHY THE PPA: some precompiled native Blender addons (e.g. SourceIO's
# pylib.abi3.so) are built against GCC 13 and need GLIBCXX_3.4.31. Stock
# Ubuntu 22.04 tops out at GLIBCXX_3.4.30, so enabling them fails with:
#   ImportError: libstdc++.so.6: version `GLIBCXX_3.4.31' not found
# libstdc++ is backward compatible, so Blender (built against the older
# one) is unaffected - we only ADD symbols.
#
# `gnupg` is required and easy to miss: add-apt-repository imports the
# PPA signing key by shelling out to gpg, and gpg cannot import into a
# keyring without gpg-agent. software-properties-common does not pull it
# in on its own, and --no-install-recommends stops anything else from
# dragging it in, so the key import exits 2 and the build dies.
# ---------------------------------------------------------------------------
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        software-properties-common \
        gnupg; \
    add-apt-repository -y ppa:ubuntu-toolchain-r/test; \
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --no-install-recommends \
        libstdc++6 \
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
    # Build-time assertion: fail loudly here rather than ship an image
    # that still can't load GCC 13 addons. grep -a reads the .so
    # directly - `strings` would need binutils, which isn't installed.
    grep -qa GLIBCXX_3.4.31 /usr/lib/x86_64-linux-gnu/libstdc++.so.6; \
    \
    # ws_server.py (shipped via manifest) streams render.log + GPU/CPU
    # samples over the websocket.
    pip3 install --no-cache-dir websockets pillow; \
    python3 -c "import websockets; print('websockets', websockets.__version__)"; \
    python3 -c "from PIL import Image; print('pillow', Image.__version__)"; \
    \
    # Only needed to add the PPA. The sources.list entry and key survive
    # the purge, so apt still works inside a running container.
    apt-get purge -y --auto-remove software-properties-common gnupg; \
    rm -rf /var/lib/apt/lists/*


# ---------------------------------------------------------------------------
# SSH for RunPod (key injected at runtime via the PUBLIC_KEY env var)
# ---------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /var/run/sshd /root/.ssh; \
    chmod 700 /root/.ssh; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config; \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config


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
