
{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:

let
  autoLoginUser = specialArgs.mainUser or null;
in
{
  services.displayManager = lib.mkIf (autoLoginUser != null) {
    autoLogin.enable = true;
    autoLogin.user = autoLoginUser;
  };
  users.users = {
    gwen = {
      isNormalUser = true;
      extraGroups = [ "networkManager" ];
    };
    ingrid = {
      isNormalUser = true;
      extraGroups = [ "networkManager" ];
    };
    bill = {
      isNormalUser = true;
      extraGroups = [ "networkManager" ];
    };
    logic11 = {
      isNormalUser = true;
      extraGroups = [ "wheel" "dialout" "networkmanager" "dialout" "docker" "plugdev" "vboxusers" ];
    };
  };
}
