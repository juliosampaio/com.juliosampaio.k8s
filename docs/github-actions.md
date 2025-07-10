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

After the VPS is ready we build the desired system configuration on the GitHub runner and copy the resulting store paths to the host using `nix copy` with the `ssh-ng` transport:

```bash
nix copy --no-check-sigs \
  --to "ssh-ng://$SSH_USER@$SSH_HOST" "$STORE_PATH"
```

Key points:

- We set `NIX_SSHOPTS` so the Action maintains a _single_ persistent SSH control connection – this avoids throttling and speeds up large copy operations.
- `--no-check-sigs` is acceptable inside CI because we trust what we just built.
- The runner polls the copy process and prints a heartbeat every 30 seconds so long transfers do not time-out.

---

## 3. Switch-to-configuration (future)

A forthcoming workflow will remotely run

```bash
sudo nix-env --profile /nix/var/nix/profiles/system --set "$STORE_PATH"
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

This activates the freshly copied closure on each node.

---

## Environment variables

| Variable                | Description                                                   |
| ----------------------- | ------------------------------------------------------------- |
| `SSH_USER` / `SSH_HOST` | Credentials of the target VPS.                                |
| `STORE_PATH`            | Derivation produced by `nix build .#<host>` in the build job. |
| `NIX_PATH`              | Pinned to `nixos-23.11` for deterministic evaluation.         |

---

## Tips for extending the pipeline

- Use matrix builds if you add more nodes – one build and copy per host.
- Cache the build output using `nix-cache-action` to speed up subsequent runs.
- Consider enabling `--gzip` compression on the `nix copy` command for very large closures.
