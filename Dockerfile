# Blender on RunPod - bare minimum image
# Build with: docker build --build-arg BLENDER_VERSION=4.4.3 --build-arg BLENDER_MAJOR=4.4 -t <user>/blender-runpod:4.4.3 .

FROM ubuntu:22.04

# Blender version - override at build time for different versions
ARG BLENDER_VERSION=4.4.3
ARG BLENDER_MAJOR=4.4

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH="/opt/blender:${PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all

# System update + Blender runtime libs + SSH + minimal utilities
# Libs match what your notebook installs, minus deprecated/unused ones.
# rclone is included for pulling assets from R2/B2 at pod startup.
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        wget \
        curl \
        xz-utils \
        ca-certificates \
        openssh-server \
        rclone \
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
        libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*


# Download and install Blender
RUN wget -qO /tmp/blender.tar.xz \
        "https://download.blender.org/release/Blender${BLENDER_MAJOR}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" && \
    mkdir -p /opt/blender && \
    tar -xf /tmp/blender.tar.xz -C /opt/blender --strip-components 1 && \
    rm /tmp/blender.tar.xz && \
    ln -s /opt/blender/blender /usr/local/bin/blender && \
    /opt/blender/blender --version



# Live browser↔pod stream: cloudflared serves the WS up via a
# *.trycloudflare.com URL; ws_server.py (shipped via manifest) uses the
# `websockets` package to push render.log + GPU/CPU samples in real time.
# Onstart's `command -v cloudflared` check skips the WS path if either
# is missing, so older pods keep working — they just fall back to the
# 5s Upstash poll.
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip && \
    pip3 install --no-cache-dir websockets pillow && \
    curl -fsSL -o /usr/local/bin/cloudflared \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 && \
    chmod +x /usr/local/bin/cloudflared && \
    cloudflared --version && \
    python3 -c "import websockets; print('websockets', websockets.__version__)" && \
    python3 -c "from PIL import Image; print('pillow', Image.__version__)" && \
    rm -rf /var/lib/apt/lists/*


# Configure SSH for RunPod (key injected at runtime via PUBLIC_KEY env var)
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

COPY start.sh /start.sh
RUN chmod +x /start.sh

WORKDIR /workspace
EXPOSE 22

CMD ["/start.sh"]
