# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };


  home = {
    username = "traverseda";
    homeDirectory = "/home/traverseda";
  };

  programs.git = {
    enable = true;
    userName = "Alex Davies";
    userEmail = "traverse.da@gmail.com";
    extraConfig = {
      core = {
        editor = "vim"; # Set default editor for Git
      };
      color = {
        ui = "auto"; # Enable colored output in the terminal
      };
      push = {
        default = "simple"; # Default push behavior to 'simple'
      };
      pull = {
        rebase = "false"; # Avoid rebasing by default on pull
      };
      credential = {
        helper = "cache --timeout=3600"; # Cache credentials for 1 hour (3600 seconds)
      };
      oh-my-zsh = {
        "hide-dirty" = "1";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  # programs.nixvim = {
  #   enable = true;
  #   defaultEditor = true; 
  #   viAlias = true;
  #   vimAlias = true;
  #  plugins.bufferline.enable = true;
  #  plugins.which-key.enable = true;
  
  #   plugins.cmp-tabby = {
  #     enable = true;
  #     host = "localhost:8337";
  #   };
  #
  #   globals.mapleader = " ";
  #   keymaps = [
  #     {
  #       mode = "n";
  #       key = "<C-a>c";
  #       options = { noremap = true; desc = "Open new terminal"; };
  #       action = "<cmd>:term<cr>";
  #     }
  #     {
  #       mode = "n";
  #       key = "<C-a>x";
  #       options = { noremap = true; desc = "Close tab"; };
  #       action = "<cmd>:bd<cr>";
  #     }
  #     {
  #       mode = "n";
  #       key = "<C-a>s";
  #       options = { noremap = true; desc = "Pick buffer"; };
  #       action = "<cmd>:BufferLinePick<CR>";
  #     }
  #     {
  #       mode = "t";
  #       key = "<Esc><Esc>";
  #       options = { noremap = true; };
  #       action = "<C-\\><C-n>";
  #     }
  #   ];
  # };

  programs.ssh = {
    enable = true; # Enable SSH module
    extraConfig = ''
      Host *
        ControlMaster auto
        ControlPath ~/.ssh/sockets/%r@%h-%p
        ControlPersist 600
    '';
  };

  home.packages = with pkgs; [
    pkgs.htop
    pkgs.zsh
    pkgs.xclip
    pkgs.ripgrep
    pkgs.mosh
    pkgs.waypipe
    pkgs.pwgen
    pkgs.chezmoi
    pkgs.neovim-remote
    pkgs.pipx
    pkgs.rclone
    pkgs.pyright
    pkgs.mosh
    pkgs.jq
    pkgs.copier
    pkgs.pv
    pkgs.poetry
    pkgs.nmap
    pkgs.dig
    pkgs.tree
    pkgs.curl
    pkgs.wget
    pkgs.wl-clipboard
    pkgs.atool
    pkgs.zig
    pkgs.comma

    (pkgs.nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Hack"]; })

    (pkgs.writeShellScriptBin "nvr-edit" ''
      nvr --remote-wait $@
    '')
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history.size = 10000;
    history.path = "${config.xdg.dataHome}/zsh/history";
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "docker-compose"];
      theme = "robbyrussell";
    };
    initExtra = ''
    if [[ -n ''${NVIM+x} ]]; then
      alias vim="nvr --remote"
      export EDITOR=nvr-edit
    fi
    '';
  };

  # Enable home-manager and git
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}
