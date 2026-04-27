# Blender on RunPod — minimal Docker image

A bare-minimum image for running Blender on RunPod with persistent SSH access.
Drops your pod spin-up time from ~1 hour to ~3 minutes.

Built and pushed entirely from GitHub Actions — no local Docker needed.

## What's in the image

- **CUDA 12.8 runtime** (Ubuntu 22.04 base) — needed for RTX 5090 / Blackwell
- **Blender** — version selected at build time via `BLENDER_VERSION` build arg
- **System libs** for headless Blender rendering (Xi, Xrender, GL, fontconfig, boost, etc.)
- **OpenSSH server** — auto-configured to use the public key RunPod injects
- **rclone** — for pulling project files from R2/B2 at pod startup

That's it. No JupyterLab, no Python ML stack, no cruft.

## One-time setup (~10 minutes, all in your browser)

### 1. Create accounts (skip ones you have)

- **GitHub** — https://github.com/signup
- **Docker Hub** — https://hub.docker.com/signup

### 2. Generate a Docker Hub access token

You'll use this so GitHub can push images to your Docker Hub account.

1. Go to https://hub.docker.com → click your avatar → **Account Settings** → **Personal access tokens**.
2. Click **Generate new token**.
3. Description: `github-actions-blender`. Permissions: **Read & Write**.
4. Click **Generate** and **copy the token now** — it won't be shown again.

### 3. Push these files to a new GitHub repo

1. On GitHub, click **+** → **New repository**. Name it whatever (e.g. `blender-runpod`). Public or private both work.
2. Click **Create repository**.
3. On the empty repo page, click **uploading an existing file** and drag in:
   - `Dockerfile`
   - `start.sh`
   - `README.md`
   - the `.github` folder (the workflow lives at `.github/workflows/build.yml`)

   If GitHub's web upload doesn't preserve folders, you can instead use **Add file → Create new file**, type `.github/workflows/build.yml` as the filename (the slashes auto-create folders), and paste the contents.

4. Commit.

### 4. Add Docker Hub credentials as GitHub secrets

In your repo: **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

Add two secrets:
- `DOCKERHUB_USERNAME` → your Docker Hub username
- `DOCKERHUB_TOKEN` → the access token from step 2

## Build and push an image

1. In your repo, click the **Actions** tab.
2. Click **Build and Push Blender Image** in the left sidebar.
3. Click **Run workflow** (top right). Fill in:
   - **Full Blender version**: `4.4.3` (or whatever you want)
   - **Major Blender version**: `4.4`
   - **Image name**: `blender-runpod` (default is fine)
4. Click **Run workflow**. Build takes 5-10 minutes.

When it finishes, your image is at:
```
docker.io/YOUR_DOCKERHUB_USERNAME/blender-runpod:4.4.3
```

To build a different version (say 4.5.0), run the workflow again with new inputs. No code changes needed.

## Use on RunPod

1. Go to **Pods** → **Deploy** → pick a 5090 (Community Cloud is fine — no network volume needed).
2. Click **Edit Template** (or "Customize Template").
3. Set **Container Image** to:
   ```
   YOUR_DOCKERHUB_USERNAME/blender-runpod:4.4.3
   ```
4. Make sure **TCP Port 22** is exposed for SSH (RunPod usually adds this automatically when it sees `EXPOSE 22`).
5. Add your SSH public key in RunPod's **Settings** → **SSH Keys** if you haven't already. RunPod injects it as the `PUBLIC_KEY` env var, and `start.sh` writes it to `authorized_keys` on every boot.
6. Deploy. Pod should be SSH-able within ~2-3 minutes.

## Connect via SSH

Once the pod is running, RunPod shows you a connect command like:
```bash
ssh root@<pod-ip> -p <port> -i ~/.ssh/id_ed25519
```

Verify Blender works:
```bash
blender --version
nvidia-smi
```

## Pull project files at pod startup (next step)

Once R2/B2 is set up, you'll add a one-liner to `start.sh` like:
```bash
rclone copy r2:my-bucket/current-project /workspace/project --transfers 16
```
And bake `rclone.conf` into the image (or pull it from a RunPod secret as an env var). We'll wire that up after Docker Hub is working.

## Adding a new Blender version later

Just run the GitHub Actions workflow again with new version inputs. Available versions are listed at https://download.blender.org/release/.

## Troubleshooting

- **Workflow fails on `Login to Docker Hub`** — your `DOCKERHUB_USERNAME` or `DOCKERHUB_TOKEN` secret is wrong. Re-create the token and update the secret.
- **Workflow fails during build with "no space left on device"** — the free-disk-space step is included to prevent this, but if it still happens, add more cleanup commands or remove the `libboost-all-dev` line in the Dockerfile (saves ~500 MB).
- **SSH connection refused on RunPod** — check that port 22 is exposed in pod settings, and that your SSH key is registered on your RunPod account.
- **Blender CUDA/OptiX errors on 5090** — make sure the Dockerfile's `CUDA_VERSION` is `12.8.0` or newer (5090 is Blackwell/sm_120, needs CUDA 12.8+).

## Optional: build locally instead

If you ever do install Docker locally, `build-and-push.sh` is included as an alternative way to build without going through GitHub Actions.
