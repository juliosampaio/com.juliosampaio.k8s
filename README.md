# com.juliosampaio.k8s

## Prerequisites

Before running the deployment pipelines it is important to have Nix already installed on the target machines. To do so, login

```sh
sh <(curl -L https://nixos.org/nix/install) --daemon
sudo systemctl enable --now nix-daemon.service
```

Configure Nix experimental flags

```sh
///etc/nix/nix.conf
experimental-features = nix-command flakes

```

experimental-features = nix-command flakes
