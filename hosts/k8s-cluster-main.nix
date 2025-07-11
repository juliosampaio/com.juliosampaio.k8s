{ pkgs, common }:

common ++ [
  pkgs.cowsay
  # k3s server binary (includes its own kubectl)
  pkgs.k3s
]
