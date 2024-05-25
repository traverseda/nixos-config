
{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }: {

  services.displayManager = {
    autoLogin.enable = true;
    autoLogin.user = "${specialArgs.mainUser}";
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
  };
}
