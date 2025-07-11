{
  description = "Multi-host Nix deployment with shared packages";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Common packages (e.g. htop)
        common = import ./hosts/common.nix { inherit pkgs; };

        # Host-specific packages (added on top of common)
        hosts = {
          k8s-cluster-main = pkgs.buildEnv {
            name = "k8s-cluster-main";
            paths = import ./hosts/k8s-cluster-main.nix { inherit pkgs common; };
          };
          k8s-cluster-node-1 = pkgs.buildEnv {
            name = "k8s-cluster-node-1";
            paths = import ./hosts/k8s-cluster-node-1.nix { inherit pkgs common; };
          };
        };
      in {
        packages = hosts;

        # Apps: handy nix run commands to deploy cluster components
        apps = {
          traefik = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "deploy-traefik" ''
              #!/usr/bin/env bash
              set -euo pipefail

              # Ensure helm is available (installed inside nix shell or system)
              if ! command -v helm &>/dev/null; then
                echo "helm is required but not found. Run inside 'nix shell nixpkgs#helm' or install helm." >&2
                exit 1
              fi

              echo "Adding Traefik chart repo…"
              helm repo add traefik https://traefik.github.io/charts
              helm repo update

              echo "Installing / upgrading Traefik…"
              helm upgrade --install traefik traefik/traefik \
                --namespace kube-system \
                --set service.type=LoadBalancer \
                --set ports.websecure.port=443
            '';
          };

          cert-manager = flake-utils.lib.mkApp {
            drv = pkgs.writeShellScriptBin "deploy-certmanager" ''
              #!/usr/bin/env bash
              set -euo pipefail

              if ! command -v helm &>/dev/null; then
                echo "helm is required but not found. Run inside 'nix shell nixpkgs#helm'." >&2
                exit 1
              fi

              echo "Adding cert-manager repo…"
              helm repo add jetstack https://charts.jetstack.io
              helm repo update

              echo "Installing / upgrading cert-manager…"
              helm upgrade --install cert-manager jetstack/cert-manager \
                --namespace cert-manager --create-namespace \
                --set installCRDs=true

              echo "Creating/patching ClusterIssuer letsencrypt-prod (email arg required) …"

              if [ "$#" -lt 1 ]; then
                echo "Usage: deploy-certmanager you@example.com" >&2
                exit 1
              fi

              EMAIL="$1"

              cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: "$EMAIL"
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: acme-account-key
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
            '';
          };
        };
      }
    );
}
