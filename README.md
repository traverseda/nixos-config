https://github.com/Misterio77/nix-starter-configs

## Notes

```bash
#Test specific hostname config
nixos-rebuild build-vm --flake ./#athame
```

```bash
#build local, push to remote
nixos-rebuild switch --flake .#hearth --target-host hearth.local --sudo --ask-sudo-password

```

```bash
#Install home manager on other linux
sh <(curl -L https://nixos.org/nix/install) --daemon
nix-shell -p home-manager
home-manager switch --impure --flake "git+https://codeberg.org/traverseda/nixos-config.git?ref=main#generic-minimal --extra-experimental-features nix-command --extra-experimental-features flakes"
```


## Building a LiveCD

To build a livecd using this flake, you can use the following command:

```bash
nix build .#nixosConfigurations.<your-configuration>.config.system.build.isoImage
```

Replace `<your-configuration>` with the name of your configuration (for example, `athame` or `metatron`). This will create an ISO image that you can burn to a CD or write to a USB stick.

Please note that the resulting livecd will be a minimal system with the same packages and configuration as your system, but without any user data. It can be used for installation or recovery purposes.
