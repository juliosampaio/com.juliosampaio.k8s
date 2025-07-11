# Mission – Enable HTTPS for the k3s Cluster via Nix

This document is a **living checklist** for folding the HTTPS stack (MetalLB → Traefik ingress → cert-manager) into our _Nix-defined_ cluster. Each numbered section can be turned into a standalone pull-request; complete it top-to-bottom.

> 📐 Guideline: **Aim for small, reviewable commits** – update docs & CI as you go. Tick `[x]` when merged.

---

## 0. Prerequisites

- [x] Control-plane + worker nodes bootstrapped via `ConfigureVPS.yaml` (done).
- [x] Domain name points to the control-plane (or MetalLB IP) – e.g. `demo.example.com`.
- [x] `K3S_CLUSTER_TOKEN`, `K8S_CLUSTER_MAIN_IP` secrets already set in GitHub.

---

## 1. Introduce an `apps/` output in the flake

- [ ] Create `apps/<system>/metalLb`, `apps/<system>/traefik`, `apps/<system>/certManager` using `pkgs.helmchart` or `pkgs.kustomize`.
- [ ] Export as `outputs.apps."${system}"` so CI can build/apply them.

Implementation hints:

```nix
outputs = { self, nixpkgs, ... }@inputs: let
  systems = [ "aarch64-linux" ];
  eachSystem = nixpkgs.lib.genAttrs systems (system: ...);
  # ...
  apps = eachSystem (system: {
    metallb = pkgs.helmTemplate "metallb" (builtins.fetchTarball ...) { # values.yaml }
  });
```

---

# NOTE: MetalLB skipped for now — single-node public IP handles 80/443 directly.

---

## 2. Traefik Ingress Controller

- [ ] Re-enable Traefik with chart `traefik/traefik`.
- [ ] Service must be `LoadBalancer` and reference MetalLB class.
- [ ] Add Helm `values.yaml` in Nix for reproducibility.

---

## 3. cert-manager

- [ ] Deploy official manifest v1.15.0 (Nix-fetched YAML or Helm chart).
- [ ] Create a `ClusterIssuer` (`letsencrypt-prod`). Parameterise email via flake `--argstr leEmail`.

---

## 4. Sample HTTPS ingress (smoke test)

- [ ] Define a demo Deployment + Service (`hello-nginx`).
- [ ] Add an `Ingress` with `cert-manager.io/cluster-issuer: letsencrypt-prod`.
- [ ] CI step: `curl -sSf https://demo.example.com` and fail if non-200.

---

## 5. Wire everything into GitHub Actions

- [ ] New job **`post-k3s-apply`** that:

  1. Copies `apps/` manifests to the control-plane via `scp`.
  2. Applies them idempotently (`kubectl apply -f`).
  3. Waits for cert to reach `Ready=True`.

- [ ] Add a health-check step to fail if Ingress isn’t reachable over HTTPS.

---

## 6. Clean-up / Documentation

- [ ] Update `docs/architecture.md` & `docs/github-actions.md` with the new stack.
- [ ] Add troubleshooting section for common ACME errors (DNS, firewall, wrong ingressClass).

---

## 7. Stretch goals (later)

- [ ] Re-introduce MetalLB (`apps.<system>.metallb`) if/when a dedicated floating IP is purchased.
- [ ] Migrate MetalLB addresses to BGP mode if provider supports it.
- [ ] Enable TLS-ALPN-01 issuer to avoid port 80.
- [ ] Integrate external-dns for automatic DNS record management via Nix.
