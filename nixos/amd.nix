{
  pkgs,
  inputs,
  ... 
}:
{
  # ===== AMD GPU Kernel Module =====
  boot.kernelModules = [ "amdgpu" ];

  # ===== AMD GPU Hardware Support =====
  hardware.amdgpu.initrd.enable = true;
  hardware.amdgpu.opencl.enable = true;

  # ===== OpenGL Support =====
  hardware.opengl.enable = true;
  hardware.opengl.driSupport32Bit = true;

  # ===== ROCm and System Packages =====
  environment.systemPackages = with pkgs; [
    # ROCm tools
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    rocmPackages.rocm-core

    # GPU monitoring
    nvtopPackages.amd

    # Utilities
    clinfo
    mesa-demos
    vulkan-tools
  ];

  # ===== User and Group Configuration =====
  users.groups.render = {};
  users.groups.video = {};

  # ===== System Settings =====
  security.unprivilegedUsernsClone = true;
}
