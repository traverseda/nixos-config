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
        losetup  # Loop device management

        # The missing essentials
        ghidra-bin # Decompiler/Disassembler (faster install than 'ghidra') <kcite ref="2"/>
        binutils   # Tools for manipulating binaries (provides 'strings', 'objdump', 'nm') <kcite ref="4"/><kcite ref="6"/>
        gdb        # Debugger

        # Highly recommended additions
        file       # Identifies file types (crucial for RE)
        radare2    # Alternative command-line RE framework
    ];
}