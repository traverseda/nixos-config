{ inputs, mkSource, ... }:

{ config, lib, pkgs, ... }:

{
  imports = [
    inputs.openclaw.homeManagerModules.openclaw
  ];

  programs.openclaw = {
    documents = ./documents;

    config = {
      gateway = {
        mode = "local";
        auth = {
          token = "<gatewayToken>"; # or set OPENCLAW_GATEWAY_TOKEN
        };
      };

      # channels.telegram = {
      #   tokenFile = "/run/agenix/telegram-bot-token";
      #   allowFrom = [
      #     12345678         # you (DM)
      #     -1001234567890   # couples group (no @mention required)
      #     -1002345678901   # noisy group (require @mention)
      #   ];
      #   groups = {
      #     "*" = { requireMention = true; };
      #     "-1001234567890" = { requireMention = false; };
      #     "-1002345678901" = { requireMention = true; };
      #   };
      # };
    };

    instances.default = {
      enable = true;
      package = pkgs.openclaw; # or inputs.openclaw.packages.${pkgs.system}.default
      stateDir = "~/.openclaw";
      workspaceDir = "~/.openclaw/workspace";
      launchd.enable = true;

      plugins = [
        { source = "${mkSource "nix-steipete-tools"}?dir=tools/oracle"; }
        { source = "${mkSource "nix-steipete-tools"}?dir=tools/peekaboo"; }
        # { source = "${mkSource "xuezh"}"; }
        # {
        #   source = "${mkSource "padel-cli"}";
        #   config = {
        #     env = { PADEL_AUTH_FILE = "/run/agenix/padel-auth"; };
        #     settings = {
        #       default_location = "CITY_NAME";
        #       preferred_times = [ "18:00" "20:00" ];
        #       preferred_duration = 90;
        #       venues = [
        #         {
        #           id = "VENUE_ID";
        #           alias = "VENUE_ALIAS";
        #           name = "VENUE_NAME";
        #           indoor = true;
        #           timezone = "TIMEZONE";
        #         }
        #       ];
        #     };
        #   };
        # }
      ];
    };
  };
}

