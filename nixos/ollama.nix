
{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    acceleration = "";
    host = "127.0.0.1";
    port = 11434;  # Local Ollama on different port
    environmentVariables = {
      OLLAMA_VULKAN = "1";
      OLLAMA_FLASH_ATTENTION = "1";
      OLLAMA_KEEP_ALIVE = "4h";
    };
  };

  services.haproxy = {
    enable = true;
    config = ''
      global
        maxconn 4096
        log /dev/log local0

      defaults
        mode http
        timeout connect 5s
        timeout client 300s
        timeout server 300s
        log global
        option httplog

      frontend ollama_frontend
        bind 127.0.0.1:11435
        default_backend ollama_backend

      backend ollama_backend
        option httpchk GET /api/tags

        # Remote server (primary) - always preferred
        server remote 192.168.192.82:11434 check inter 2s fall 3 rise 2

        # Local server (backup only) - used only when remote fails
        server local 127.0.0.1:11434 check inter 2s fall 3 rise 2 backup
    '';
  };

  environment.variables = {
    OLLAMA_HOST = "http://127.0.0.1:11435";
  };

  environment.systemPackages = [
    pkgs.ollama-vulkan
    (pkgs.writeShellScriptBin "local-ollama" ''
      OLLAMA_HOST=http://127.0.0.1:11434 ${pkgs.ollama-vulkan}/bin/ollama "$@"
    '')
    (pkgs.writeShellScriptBin "remote-ollama" ''
      OLLAMA_HOST=http://192.168.192.82:11434 ${pkgs.ollama-vulkan}/bin/ollama "$@"
    '')
  ];
}
