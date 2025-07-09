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
      }
    );
}
