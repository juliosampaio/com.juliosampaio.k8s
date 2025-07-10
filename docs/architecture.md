# Project Architecture

This repository defines a **declarative, reproducible Kubernetes cluster** using Nix flakes. The main pieces are outlined below.

---

## 1. Flake root

```
.
├── flake.nix     # entry-point – exposes packages, apps & nixosConfigurations
├── flake.lock    # pins all dependencies for reproducibility
└── hosts/        # host-specific module lists
```

The flake exposes an output like `nixosConfigurations."k8s-cluster-main"` that the CI pipeline builds into a system closure.

---

## 2. `hosts/` directory

Each file returns a list of _NixOS modules_ that make up a machine.

| File                     | Purpose                                                               |
| ------------------------ | --------------------------------------------------------------------- |
| `common.nix`             | Modules shared by all nodes (e.g. `htop`).                            |
| `k8s-cluster-main.nix`   | Adds base utilities (`pkgs.cowsay`) to the control-plane node.        |
| `k8s-cluster-node-1.nix` | Example worker node – includes a `dinosay` script on top of `common`. |

Because the files only return lists, they can easily be composed inside the flake outputs:

```nix
{ pkgs, ... }:
{
  nixosConfigurations.k8s-cluster-main = nixpkgs.lib.nixosSystem {
    modules = import ./hosts/k8s-cluster-main.nix;
  };
}
```

---

## 3. CI / CD flow

1. **ConfigureVPS** – installs Nix on fresh VPS instances and patches the environment so `nix-daemon` is on the PATH.
2. **Build** – Runner evaluates the flake and builds the relevant `nixosConfiguration`, producing a `/nix/store/<hash>-k8s-cluster-…` closure.
3. **Copy** – `nix copy` streams the closure to the remote host using the `ssh-ng` protocol.
4. **Activation** – (coming soon) a `switch` step will make the new system live.

---

## 4. Why Nix + Flakes?

- **Immutability** – every change produces a new store path; rollbacks are trivial.
- **Composability** – modules can be freely combined to produce tailored node roles.
- **Reproducibility** – the lock file guarantees byte-for-byte identical systems across machines and over time.

---

## 5. Future enhancements

- Add a Hydra or Cachix binary cache to speed up deployments.
- Expand host roles (e.g. ingress, monitoring) as additional files in `hosts/`.
- Generate Kubernetes manifests from Nix as the next logical layer.
