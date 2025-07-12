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

Each file now returns a **plain list of packages** (wrapped in a `pkgs.buildEnv`) that will be installed into the user's _profile_ on a vanilla Debian VPS. No NixOS required.

| File                     | Purpose                                                                  |
| ------------------------ | ------------------------------------------------------------------------ |
| `common.nix`             | Packages shared by all nodes (e.g. `htop`).                              |
| `k8s-cluster-main.nix`   | Control-plane extras – `pkgs.cowsay` and **`pkgs.k3s` (server binary)**. |
| `k8s-cluster-node-1.nix` | Worker extras – a `dinosay` helper plus **`pkgs.k3s` (agent binary)**.   |

Because they are just lists the flake can expose them directly under `packages.<system>.<host>`:

```nix
outputs = { self, nixpkgs, flake-utils, ... }:
  flake-utils.lib.eachDefaultSystem (system:
    {
      packages.k8s-cluster-main = import ./hosts/k8s-cluster-main.nix { inherit pkgs common; };
    });
```

---

## 3. CI / CD flow

1. **ConfigureVPS** – installs Nix (if missing) and prepares `/etc/nix/nix.conf`.
2. **Build** – Runner builds the **package closure** for each host (control-plane & worker).
3. **Copy** – `nix copy` pushes the closure to the node via `ssh-ng`.
4. **Activate** – `nix-env --set <closure>` atomically switches the user profile.
5. **Configure k3s** – uses the official _k3s installer_ with `INSTALL_K3S_SKIP_DOWNLOAD=true` so it re-uses the Nix-built binary, generating a systemd unit (server on the control plane, agent on workers).
6. **Deploy Ingress Stack** – installs Traefik and cert-manager using official Helm binaries for maximum compatibility.

---

## 4. Ingress and HTTPS Infrastructure

The cluster includes a complete ingress and HTTPS setup:

### Traefik Ingress Controller

- **Installation**: Via official Helm chart (v25.0.0)
- **Configuration**: Automatic HTTP to HTTPS redirects
- **Namespace**: `kube-system`
- **Purpose**: Modern, lightweight ingress controller

### cert-manager

- **Installation**: Via official Helm chart (v1.13.3)
- **Configuration**: Automatic Let's Encrypt certificate management
- **Namespace**: `cert-manager`
- **ClusterIssuer**: `letsencrypt-prod` for production certificates

### Hybrid Approach

- **Nix-built k3s**: Reliable and reproducible
- **Official Helm binary**: Avoids X11/pinentry issues in headless environments
- **k3s-bundled kubectl**: Always compatible with the cluster version

---

## 5. Why Nix + Flakes?

- **Immutability** – every change produces a new store path; rollbacks are trivial.
- **Composability** – modules can be freely combined to produce tailored node roles.
- **Reproducibility** – the lock file guarantees byte-for-byte identical systems across machines and over time.
- **Hybrid flexibility** – use Nix where it excels, official binaries where needed.

---

## 6. Application Deployment

Applications can now be deployed with automatic HTTPS certificates:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  tls:
    - hosts:
        - your-domain.com
      secretName: your-app-tls
  rules:
    - host: your-domain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: your-app-service
                port:
                  number: 80
```

---

## 7. Future enhancements

- Add a Hydra or Cachix binary cache to speed up deployments.
- Expand host roles (monitoring, storage) as additional files in `hosts/`.
- Define Kubernetes workloads (Helm charts) in the flake for reproducible app deploys.
- Add monitoring stack (Prometheus, Grafana).
- Implement backup and disaster recovery procedures.
