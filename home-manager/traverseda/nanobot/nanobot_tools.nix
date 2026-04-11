{ config, pkgs, inputs, lib, ... }:
let

  #ToDo: Most of these security features barely work. Nanobot can see itself in /proc and thus see a bunch of extra env vars.
  # All private env vars are getting passed to MCP servers.
  # Generally just firejail's approach of starting from a pretty open shell and then locking it down is not great.
  python = pkgs.python313;

  baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
    inherit python;
  };

  mkUvScriptEnv = scriptFile:
    let
      script = inputs.uv2nix.lib.scripts.loadScript {
        script = ./tools + "/${scriptFile}";
      };
      overlay = script.mkOverlay { sourcePreference = "wheel"; };
      pythonSet = baseSet.overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          overlay
        ]
      );
    in
      script.mkVirtualEnv { inherit pythonSet; };

   mkMcpBundle = name: tool:                                                                                                                                                                   
     let                                                                                                                                                                                       
       execScript = pkgs.writeShellScript "mcp-${name}-exec" ''                                                                                                                                
         exec /run/wrappers/bin/firejail \                                                                                                                                                     
           ${lib.concatStringsSep " \\\n              " tool.firejailArgs} \                                                                                                                   
           ${lib.concatStringsSep " \\\n              " (map (v: "--env=${v}=\"\$${v}\"") tool.env)} \                                                                                         
           -- ${tool.package}/bin/${tool.bin}                                                                                                                                                  
       '';                                                                                                                                                                                     
     in                                                                                                                                                                                        
     {                                                                                                                                                                                         
       # Note the '@' - this tells systemd it is a template for Accept=true                                                                                                                    
       "mcp-${name}@" = {                                                                                                                                                                      
         Unit = {                                                                                                                                                                              
           Description = "Sandboxed MCP gateway for ${name}";                                                                                                                                  
         };                                                                                                                                                                                    
         Service = {                                                                                                                                                                           
           # Systemd passes the already-accepted connection here                                                                                                                               
           StandardInput = "socket";                                                                                                                                                           
           StandardOutput = "socket";                                                                                                                                                          
           StandardError = "journal";                                                                                                                                                          
                                                                                                                                                                                               
           # Bridge the connected socket (-) to a pipe (EXEC) for Firejail                                                                                                                     
           ExecStart = "${pkgs.socat}/bin/socat - EXEC:\"${pkgs.bash}/bin/bash --login ${execScript}\"";                                                                                       
                                                                                                                                                                                               
           Restart = "on-failure";                                                                                                                                                             
           RestartSec = "2s";                                                                                                                                                                  
         };                                                                                                                                                                                    
       };                                                                                                                                                                                      
       socket = {                                                                                                                                                                              
         Unit.Description = "Socket for Sandboxed MCP gateway ${name}";                                                                                                                        
         Socket = {                                                                                                                                                                            
           ListenStream = "%t/mcp/${name}.sock";                                                                                                                                               
           # This triggers the creation of a new service instance per connection                                                                                                               
           Accept = true;                                                                                                                                                                      
           SocketMode = "0600";                                                                                                                                                                
           DirectoryMode = "0700";                                                                                                                                                             
           RemoveOnStop = true;                                                                                                                                                                
         };                                                                                                                                                                                    
         Install.WantedBy = [ "sockets.target" "mcp.target" ];                                                                                                                                 
       };                                                                                                                                                                                      
     };     

                                                            
  mcpConnect = pkgs.writeShellScriptBin "mcp-connect" ''
    name="$1"
    if [[ -z "$name" ]]; then
      echo "Usage: mcp-connect <server-name>" >&2
      exit 1
    fi
    exec ${pkgs.socat}/bin/socat \
      STDIO \
      "UNIX-CONNECT:/run/user/$(id -u)/mcp/$name.sock"
  '';

  nanobotEnv = mkUvScriptEnv "nanobot.py";

  nanobotSandboxed = pkgs.writeShellScriptBin "nanobot" ''
    # Run as an interactive login shell to ensure KWallet env vars are sourced
    # and that the shell initialization (which might have interactive guards) is fully processed.
    exec ${pkgs.bash}/bin/bash -li -c '
      exec /run/wrappers/bin/firejail \
        --caps.drop=all \
        --env=XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR}" \
        --env=OPENROUTER_API_KEY="''${OPENROUTER_API_KEY}" \
        --whitelist="${config.home.homeDirectory}/.nanobot" \
        --whitelist="$XDG_RUNTIME_DIR/mcp" \
        --no3d --nodvd --nosound --notv --nou2f --novideo \
        -- ${nanobotEnv}/bin/nanobot "$@"
    ' "nanobot" "$@"
  '';

in
{
 
  _module.args = { inherit mkUvScriptEnv mkMcpBundle mcpConnect nanobotSandboxed; };
}
