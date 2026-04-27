# Blender on RunPod - bare minimum image
# Build with: docker build --build-arg BLENDER_VERSION=4.4.3 --build-arg BLENDER_MAJOR=4.4 -t <user>/blender-runpod:4.4.3 .

ARG CUDA_VERSION=12.8.0
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04

# Blender version - override at build time for different versions
ARG BLENDER_VERSION=4.4.3
ARG BLENDER_MAJOR=4.4

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PATH="/opt/blender:${PATH}"

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
        libfontconfig1 \
        libboost-all-dev \
    && rm -rf /var/lib/apt/lists/*

# Download and install Blender
RUN wget -qO /tmp/blender.tar.xz \
        "https://download.blender.org/release/Blender${BLENDER_MAJOR}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" && \
    mkdir -p /opt/blender && \
    tar -xf /tmp/blender.tar.xz -C /opt/blender --strip-components 1 && \
    rm /tmp/blender.tar.xz && \
    /opt/blender/blender --version

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
