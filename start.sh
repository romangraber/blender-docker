#!/bin/bash
set -e

# RunPod injects the SSH key as PUBLIC_KEY, Vast.ai as SSH_PUBLIC_KEY.
# Check for either.
SSH_KEY="${PUBLIC_KEY:-${SSH_PUBLIC_KEY:-}}"

if [ -n "$SSH_KEY" ]; then
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "[start.sh] SSH key installed."
else
    echo "[start.sh] WARNING: no SSH key env var set - SSH login will fail."
fi

ssh-keygen -A
/opt/blender/blender --version || true
exec /usr/sbin/sshd -D -e
