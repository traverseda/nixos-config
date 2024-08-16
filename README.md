https://github.com/Misterio77/nix-starter-configs

## Notes

```bash
#Test specific hostname config
nixos-rebuild build-vm --flake ./#athame
```

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
home-manager switch --flake git+https://codeberg.org/traverseda/nixos-config.git?ref=main#traverseda@generic --extra-experimental-features nix-command --extra-experimental-features flakes
```


## Building a LiveCD

To build a livecd using this flake, you can use the following command:

```bash
nix build .#nixosConfigurations.<your-configuration>.config.system.build.isoImage
```

Replace `<your-configuration>` with the name of your configuration (for example, `athame` or `metatron`). This will create an ISO image that you can burn to a CD or write to a USB stick.

Please note that the resulting livecd will be a minimal system with the same packages and configuration as your system, but without any user data. It can be used for installation or recovery purposes.
