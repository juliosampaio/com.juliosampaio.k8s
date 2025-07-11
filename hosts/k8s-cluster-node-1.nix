{ pkgs, common }:

let
  dinosay = pkgs.writeShellScriptBin "dinosay" ''
    exec ${pkgs.cowsay}/bin/cowsay -f trex "$@"
  '';
in

common ++ [
  dinosay
  # k3s agent binary (same version as control-plane)
  pkgs.k3s
]
