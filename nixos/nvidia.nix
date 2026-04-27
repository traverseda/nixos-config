{
   pkgs,
    ... 
}:
{
  boot.kernelModules = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # Set to true for open-source drivers
    nvidiaSettings = true;
  };

  virtualisation.docker = {
    daemon.settings = {
      runtimes = {
        nvidia = {
          path = "nvidia-container-runtime";
          runtimeArgs = [];
        };
      };
    };
  };

  # Add NVIDIA tools and GPU monitoring
  environment.systemPackages = with pkgs; [
    nvidia-utils
    nvtop
  ];
}
