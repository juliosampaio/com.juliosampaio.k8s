# GitHub Actions CI/CD Pipelines

This repository relies on GitHub Actions to build, test and deploy the Nix-based Kubernetes cluster configuration defined in this flake. Below is an overview of the current workflows and jobs.

---

## 1. ConfigureVPS

**File:** `.github/workflows/ConfigureVPS.yaml`

Bootstraps every target VPS so it is ready to receive Nix closures and activate the new system profile.

| Step               | Purpose                                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Checkout**       | Fetch the repository code so later steps can read the flake.                                                                                                                                                                                                                                                                                                                                                         |
| **Bootstrap Nix**  | Runs remotely via `appleboy/ssh-action`.<br/>If `nix` is _not_ found on the VPS:<br/>1. Removes artefacts from aborted installs (`*backup-before-nix`).<br/>2. Installs minimal Debian dependencies (`xz-utils curl sudo`).<br/>3. Executes the official installer in non-interactive _daemon_ mode (`--daemon --yes`).<br/>Finally it ensures `nix-daemon` is discoverable by adding a symlink in `/usr/local/bin`. |
| **Write nix.conf** | Appends common options such as experimental flakes support, disables signature checking inside CI and grants `trusted-users`.                                                                                                                                                                                                                                                                                        |
| **PATH snippet**   | Installs `/etc/profile.d/nix-user-profile.sh` so users who ssh in later get their `~/.nix-profile/bin` on the `PATH`.                                                                                                                                                                                                                                                                                                |

The job is **idempotent** – re-running it on an already-configured host is a no-op.

---

## 2. Build & Copy

After bootstrapping, the runner builds each host's **package closure** (a simple `pkgs.buildEnv`) instead of a full NixOS system and copies it to the node with `nix copy` using the `ssh-ng` transport:

```bash
nix copy --no-check-sigs \
  --to "ssh-ng://$SSH_USER@$SSH_HOST" "$STORE_PATH"
```

Key points:

- We set `NIX_SSHOPTS` so the Action maintains a _single_ persistent SSH control connection – this avoids throttling and speeds up large copy operations.
- `--no-check-sigs` is acceptable inside CI because we trust what we just built.
- The runner polls the copy process and prints a heartbeat every 30 seconds so long transfers do not time-out.

---

## 3. Activate profile

On the remote host the job executes

```bash
nix-env --profile $HOME/.nix-profile --set "$STORE_PATH"
```

which atomically swaps the user profile to the new closure (no service interruption).

## 4. Configure k3s

Finally the workflow runs **one more SSH step** per host that:

1. Ensures the Nix-built `k3s` binary is on `$PATH`.
2. Invokes the official installer with `INSTALL_K3S_SKIP_DOWNLOAD=true` so it only generates/updates the systemd unit:

```bash
curl -sfL https://get.k3s.io | env \
  INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_BIN_DIR="$HOME/.nix-profile/bin" \
  K3S_TOKEN="$K3S_TOKEN" \
  sh -s - server   # or "agent --server https://$SERVER_IP:6443"
```

This step is **idempotent**; re-running it leaves a healthy cluster untouched.

---

## 5. Deploy Ingress Stack

**Job:** `deploy-ingress` (runs after `deploy` completes)

Installs Traefik and cert-manager to provide ingress and automatic HTTPS certificates:

| Step                     | Purpose                                                                                          |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| **Wait for k3s**         | Ensures the cluster is ready before proceeding.                                                  |
| **Setup kubectl**        | Creates kubectl symlink and configures kubeconfig with proper permissions.                       |
| **Install Helm**         | Downloads and installs the official Helm binary (v3.14.2) to avoid Nix-built version X11 issues. |
| **Install Traefik**      | Installs Traefik v25.0.0 via Helm with HTTPS redirects and TLS enabled.                          |
| **Install cert-manager** | Installs cert-manager v1.13.3 via Helm with CRDs and Let's Encrypt integration.                  |
| **Create ClusterIssuer** | Sets up `letsencrypt-prod` ClusterIssuer for automatic SSL certificate generation.               |
| **Verify installation**  | Confirms all components are running and ready.                                                   |

**Key features:**

- **Idempotent**: Safe to run multiple times, upgrades existing installations
- **Hybrid approach**: Uses official Helm binary for maximum compatibility
- **Automatic HTTPS**: Ready for applications with automatic SSL certificates
- **Error handling**: Robust timeout and error handling throughout

---

## Environment variables

| Variable / Secret          | Description                                                                 |
| -------------------------- | --------------------------------------------------------------------------- |
| `SSH_USER`, `SSH_PASSWORD` | Credentials of each target VPS (one pair per matrix entry).                 |
| `${HOST}_IP`               | IP address of each host, used by the Actions matrix.                        |
| `STORE_PATH`               | Output of `nix build .#packages.<system>.<host>`.                           |
| `K3S_CLUSTER_TOKEN`        | Shared secret all nodes use to join the cluster.                            |
| `K8S_CLUSTER_MAIN_IP`      | Address of the control-plane node, injected into the worker's systemd unit. |
| `LETSENCRYPT_EMAIL`        | Email address for Let's Encrypt notifications and account registration.     |
| `NIX_PATH`                 | Pinned to `nixos-23.11` for deterministic evaluation.                       |

---

## Required GitHub Secrets

For the complete setup, you need these secrets in your repository:

| Secret Name                  | Description                                   | Example                               |
| ---------------------------- | --------------------------------------------- | ------------------------------------- |
| `K8S_CLUSTER_MAIN_IP`        | Control-plane VPS IP address                  | `192.168.1.100`                       |
| `K8S_CLUSTER_MAIN_USER`      | Control-plane VPS username                    | `debian`                              |
| `K8S_CLUSTER_MAIN_PASSWORD`  | Control-plane VPS password                    | `your-password`                       |
| `K8S_CLUSTER_NODE1_IP`       | Worker node VPS IP address                    | `192.168.1.101`                       |
| `K8S_CLUSTER_NODE1_USER`     | Worker node VPS username                      | `debian`                              |
| `K8S_CLUSTER_NODE1_PASSWORD` | Worker node VPS password                      | `your-password`                       |
| `K3S_CLUSTER_TOKEN`          | Shared token for cluster joining              | `K10c4b8c1c2c3c4c5c6c7c8c9c0`         |
| `LETSENCRYPT_EMAIL`          | Email for Let's Encrypt notifications         | `admin@yourdomain.com`                |
| `SSH_PRIVATE_KEY`            | SSH private key for passwordless file copying | `-----BEGIN OPENSSH PRIVATE KEY-----` |

---

## Tips for extending the pipeline

- Use matrix builds if you add more nodes – one build and copy per host.
- Cache the build output using `nix-cache-action` to speed up subsequent runs.
- Consider enabling `--gzip` for faster transfers.
- The ingress stack deployment is designed to be idempotent and safe to re-run.
- Monitor the GitHub Actions logs for detailed deployment progress and troubleshooting.
