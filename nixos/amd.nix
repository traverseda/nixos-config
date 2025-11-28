{
   pkgs,
    ... 
}:
{
  boot.kernelModules = [ "amdgpu" ];


#   #docker run --rm --runtime=amd --gpus all rocm/pytorch:latest rocm-smi
#   virtualisation.docker = {
#     daemon.settings = {
#       runtimes = {
#         amd = {
#           path = "${pkgs.rocmPackages.rocm-core}/bin/amd-container-runtime";
#           runtimeArgs = [];
#         };
#       };
#     };
#   }; 
## Does not work

  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.opencl.enable = true;

  # Add ROCm tools and GPU monitoring
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    nvtopPackages.amd
  ];
}
