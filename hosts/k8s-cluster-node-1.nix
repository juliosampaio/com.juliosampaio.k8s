{ pkgs, common }:

let
  dinosay = pkgs.writeShellScriptBin "dinosay" ''
    exec ${pkgs.cowsay}/bin/cowsay -f trex "$@"
  '';
in

common ++ [
  dinosay
]
