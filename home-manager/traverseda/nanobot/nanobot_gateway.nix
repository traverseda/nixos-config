{ config, lib, pkgs, nanobotSandboxed, ... }:

{
  systemd.user.services.nanobot-gateway = {
    Unit = {
      Description = "Nanobot Gateway Service";
      After = [ "network.target" "mcp.target" ];
      Wants = [ "mcp.target" ];
    };

    Service = {
      ExecStart = "${nanobotSandboxed}/bin/nanobot gateway";
      Restart = "always";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
