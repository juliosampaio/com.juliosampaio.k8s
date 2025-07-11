# com.juliosampaio.k8s

_Nix-powered, fully reproducible Kubernetes cluster definitions plus CI/CD pipelines._

---

## Overview

This repository manages the configuration of a small Kubernetes cluster (control-plane + worker nodes) **entirely with Nix flakes on top of vanilla Debian VPSs**. Each host’s desired _package list_ is declared in the `hosts/` directory and built & deployed automatically by GitHub Actions.

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
├── hosts/                   # Per-node package lists
├── docs/                    # Project and pipeline documentation
└── .github/workflows/       # CI/CD definitions
```

A detailed explanation of each part lives in [`docs/architecture.md`](docs/architecture.md).

---

## CI / CD

GitHub Actions builds each host’s package closure and deploys it, then provisions k3s, on every push to `main`. Details live in [`docs/github-actions.md`](docs/github-actions.md).

---

## Quick start

1. **Prepare your VPS instances** (Debian/Ubuntu tested) – ensure you can SSH in as a user with sudo privileges.
2. **Set repository secrets**
   - `K8S_CLUSTER_MAIN_IP` – control-plane IP the workers will join.
   - `K3S_CLUSTER_TOKEN` – shared token all nodes use when registering.
   - Per-host credentials (`<HOST>_USER`, `<HOST>_PASSWORD`, `<HOST>_IP`).
3. **Push a commit** → GitHub Actions will:
   1. Install Nix (if missing) on the node.
   2. Build the host’s package closure (`nix build .#packages.<system>.<host>`).
   3. Copy & activate the closure (atomic `nix-env --set`).
   4. Generate / update a `k3s` systemd unit (server or agent) using the Nix-built binary.

---

## Local development

```bash
# build the control-plane package closure locally
nix build .#packages.aarch64-linux.k8s-cluster-main

# run nix repl to inspect outputs
nix repl flake:nixosConfigurations.k8s-cluster-node-1
```

---

## Prerequisites (manual install)

If you want to test outside CI you need Nix **multi-user** mode (daemon):

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
