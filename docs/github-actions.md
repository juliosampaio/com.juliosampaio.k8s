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

After bootstrapping, the runner builds each host’s **package closure** (a simple `pkgs.buildEnv`) instead of a full NixOS system and copies it to the node with `nix copy` using the `ssh-ng` transport:

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

## Environment variables

| Variable / Secret          | Description                                                                 |
| -------------------------- | --------------------------------------------------------------------------- |
| `SSH_USER`, `SSH_PASSWORD` | Credentials of each target VPS (one pair per matrix entry).                 |
| `${HOST}_IP`               | IP address of each host, used by the Actions matrix.                        |
| `STORE_PATH`               | Output of `nix build .#packages.<system>.<host>`.                           |
| `K3S_CLUSTER_TOKEN`        | Shared secret all nodes use to join the cluster.                            |
| `K8S_CLUSTER_MAIN_IP`      | Address of the control-plane node, injected into the worker’s systemd unit. |
| `NIX_PATH`                 | Pinned to `nixos-23.11` for deterministic evaluation.                       |

---

## Tips for extending the pipeline

- Use matrix builds if you add more nodes – one build and copy per host.
- Cache the build output using `nix-cache-action` to speed up subsequent runs.
- Consider enabling `--gzip`
