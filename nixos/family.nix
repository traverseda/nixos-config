
{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }: {

  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "${specialArgs.mainUser}";
  }; 
  users.users = {
    gwen = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      isNormalUser = true;
      extraGroups = [ "networkManager" ];
    };
  };
}
