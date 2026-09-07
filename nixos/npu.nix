# AMD Ryzen AI NPU (XDNA2) support, for testing FastFlowLM.
# amdxdna is in-tree since kernel 7.0, so no out-of-tree driver is needed here.
# XRT + the amdxdna shim plugin are packaged locally in ../pkgs/xrt and
# ../pkgs/xrt-plugin-amdxdna (adapted from https://github.com/robcohen/nix-amd-npu).
{
  config,
  lib,
  pkgs,
  ...
}: {
  # The "video" group exists by default but has no members - without this,
  # the udev rule below grants access to a group nobody is actually in.
  users.groups.video.members = ["traverseda"];

  boot.kernelModules = ["amdxdna"];

  # SVA (Shared Virtual Addressing) requires IOMMU translated mode, not passthrough
  boot.kernelParams = ["iommu.passthrough=0"];

  services.udev.extraRules = ''
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", GROUP="video", MODE="0660"
  '';

  # The NPU driver needs to mmap large (64MB+) DMA buffers.
  security.pam.loginLimits = [
    {
      domain = "@video";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@video";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  environment.systemPackages = [pkgs.xrt-amdxdna pkgs.fastflowlm];

  environment.variables = {
    XILINX_XRT = "${pkgs.xrt-amdxdna}/opt/xilinx/xrt";
  };
}
