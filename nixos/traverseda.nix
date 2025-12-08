{ config, lib, pkgs, modulesPath, inputs, ... }:
{
  
fileSystems."/mnt/hekate" = {
  device = "traverseda@10.147.17.213:/main/subvol-100-disk-0";
  fsType = "sshfs";
  options = [
    "nodev"
    "noatime"
    "allow_other"
    "IdentityFile=/home/traverseda/.ssh/id_ed25519"
    "nofail"
    "x-systemd.device-timeout=5"
    "x-systemd.automount"
  ];
};


}