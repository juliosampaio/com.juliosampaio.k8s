# com.juliosampaio.k8s

_Nix-powered, fully reproducible Kubernetes cluster definitions plus CI/CD pipelines._

---

## Overview

This repository manages the configuration of a small Kubernetes cluster (control-plane + worker nodes) **entirely with Nix flakes**. Each node’s NixOS configuration is declared in the `hosts/` directory and built & deployed automatically by GitHub Actions.

Key goals:

- **Reproducibility** – a single commit fully describes a node.
- **Idempotent automation** – pipelines can be re-run at any time without manual clean-up.
- **Ease-of-use** – minimal host setup; everything is bootstrapped from CI.

---

## Repository structure

```
.
├── flake.nix                # Entry point – defines outputs
├── flake.lock               # Pin of all Nix inputs
├── hosts/                   # Per-node module lists
├── docs/                    # Project and pipeline documentation
└── .github/workflows/       # CI/CD definitions
```

A detailed explanation of each part lives in [`docs/architecture.md`](docs/architecture.md).

---

## CI / CD

GitHub Actions builds the system closures and deploys them to the nodes on every push to `main`. The workflow is documented in [`docs/github-actions.md`](docs/github-actions.md).

---

## Quick start

1. **Prepare your VPS instances** (Debian/Ubuntu tested) – ensure you can SSH in as a user with sudo privileges.
2. **Set repository secrets**
   - `SSH_USER`, `SSH_HOST` – credentials for each node (or use encrypted files + matrix).
3. **Push a commit** → GitHub Actions will:
   1. Install Nix (`--daemon --yes`) on the node if missing.
   2. Build the node’s NixOS closure.
   3. Copy the closure via `ssh-ng`.
   4. (Coming soon) switch the node to the new configuration.

---

## Local development

```bash
# build the control-plane system locally
nix build .#nixosConfigurations.k8s-cluster-main.config.system.build.toplevel

# run nix repl to inspect outputs
nix repl flake:nixosConfigurations.k8s-cluster-node-1
```

---

## Prerequisites (manual install)

If you want to test outside CI you need Nix **multi-user** mode:

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon --yes
sudo systemctl enable --now nix-daemon.service

# enable experimental flakes support
sudo mkdir -p /etc/nix
echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf
```

The CI job performs the same steps automatically when provisioning a new node.

---

## License

MIT © 2024 Julio Sampaio
