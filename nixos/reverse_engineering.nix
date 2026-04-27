{
  config,
  pkgs,
  # system,
  inputs,
  #  lib,
  #  ros,
  ...
}:
{
    environment.systemPackages = with pkgs; [
        # Your current tools
        imhex    # Hex Editor
        binwalk  # Firmware Analysis
        util-linux  # Loop device management

        # The missing essentials
        ghidra-bin # Decompiler/Disassembler (faster install than 'ghidra')
        binutils   # Tools for manipulating binaries (provides 'strings', 'objdump', 'nm')
        gdb        # Debugger

        # Highly recommended additions
        file       # Identifies file types (crucial for RE)
        radare2    # Alternative command-line RE framework
    ];
}