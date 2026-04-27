#!/bin/bash
set -e

# RunPod injects your SSH public key as the PUBLIC_KEY env variable.
# This script writes it to authorized_keys so you can SSH in.
if [ -n "$PUBLIC_KEY" ]; then
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "[start.sh] SSH key installed."
else
    echo "[start.sh] WARNING: no PUBLIC_KEY env var set - SSH login will fail."
fi

# Generate host keys on first boot
ssh-keygen -A

# Show Blender version in pod logs for sanity
/opt/blender/blender --version || true

# Start sshd in foreground so the container stays alive
exec /usr/sbin/sshd -D -e
