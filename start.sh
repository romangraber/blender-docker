#!/bin/bash
set -e

# --- SSH key injection ---
# RunPod injects the SSH key as PUBLIC_KEY, Vast.ai as SSH_PUBLIC_KEY.
SSH_KEY="${PUBLIC_KEY:-${SSH_PUBLIC_KEY:-}}"
if [ -n "$SSH_KEY" ]; then
    echo "$SSH_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "[start.sh] SSH key installed."
else
    echo "[start.sh] WARNING: no SSH key env var set - SSH login will fail."
fi

# --- R2 credentials (passed as env vars at pod launch) ---
# The image itself contains no credentials. They are injected by the platform
# (RunPod/Vast) at launch time and a temporary rclone config is written here.
if [ -n "$R2_ACCESS_KEY_ID" ] && [ -n "$R2_SECRET_ACCESS_KEY" ] && [ -n "$R2_ENDPOINT" ]; then
    mkdir -p /root/.config/rclone
    cat > /root/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = $R2_ACCESS_KEY_ID
secret_access_key = $R2_SECRET_ACCESS_KEY
endpoint = $R2_ENDPOINT
region = auto
acl = private
no_check_bucket = true
EOF
    chmod 600 /root/.config/rclone/rclone.conf
    echo "[start.sh] rclone configured for R2."

    # Optional: auto-pull a job folder if R2_JOB_PATH is set.
    # Format: bucket/path/to/job  (e.g. blender-jobs/jobs/test001)
    if [ -n "$R2_JOB_PATH" ]; then
        echo "[start.sh] Pulling r2:$R2_JOB_PATH into /workspace ..."
        rclone copy "r2:$R2_JOB_PATH" /workspace --transfers 16 --progress || \
            echo "[start.sh] WARNING: rclone copy failed."
    fi
else
    echo "[start.sh] No R2 credentials provided - skipping rclone setup."
fi

ssh-keygen -A
/opt/blender/blender --version || true
exec /usr/sbin/sshd -D -e
