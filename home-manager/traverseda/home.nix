# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  outputs,
  # lib,
  config,
  pkgs,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    inputs.nix-index-database.hmModules.nix-index
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

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    #We use bufferline for the top line
    plugins.bufferline.enable = true;
    #And lualine for the bottom line
    plugins.lualine = {
      enable = true;
      sections = {
        lualine_c = [ "os.date('%X')"];
        lualine_x = [
          {name= "hostname";}
        ];

      };
    };

    #Enable which key
    plugins.which-key.enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      vim-suda
    ];

    #enable autocomplete
    plugins.cmp = {
      enable = true;
      settings = {
        mapping = {
          __raw = ''
            cmp.mapping.preset.insert({
            ['<C-j>'] = cmp.mapping.select_next_item(),
            ['<C-k>'] = cmp.mapping.select_prev_item(),
            ['<C-e>'] = cmp.mapping.abort(),

            ['<C-b>'] = cmp.mapping.scroll_docs(-4),

             ['<C-f>'] = cmp.mapping.scroll_docs(4),

             ['<C-Space>'] = cmp.mapping.complete(),

             ['<CR>'] = cmp.mapping.confirm({ select = true }),

             ['<S-CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
            })
          '';
        };
        sources = [
          {name = "path";}
          {name = "nvim_lsp";}
          {name = "buffer";}
          {name = "treesitter";}
          {name = "copilot";}
          {name = "bash";}
        ];
      };
    };
    plugins.indent-blankline.enable = true;
    plugins.lsp-format.enable = true;
    plugins.lsp.servers.bashls.package = "";
    plugins.lsp = {
      enable = true;
    };
    plugins.lsp-lines.enable = true;
    plugins.lint = {
      enable = true;
    };
    plugins.nix.enable = true;

    plugins.clipboard-image = {
        enable = true;
        clipboardPackage = pkgs.xclip;
    };

    colorschemes.tokyonight = {
      enable = true;
      settings.style = "night";
    };

    extraConfigLua = ''
      -- Automatically enter insert mode when opening a terminal
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "*",
        command = "startinsert"
      })
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "term://*",
        command = "startinsert"
      })
      -- Open files with sudo if needed
      vim.g.suda_smart_edit = 1
      -- Make my cursor a block
      vim.opt.guicursor = "n-v-c:block"
      -- Disable ctrl+a incrementing numbers
      vim.api.nvim_set_keymap('i', '<C-a>', '<nop>', { noremap = true })
      -- Use system clipboard by default
      vim.opt.clipboard:append("unnamedplus")
      -- Keep selection when changing indentation
      -- keep visual mode after indent
      vim.api.nvim_set_keymap('v', '<', '<gv', { noremap = true })
      vim.api.nvim_set_keymap('v', '>', '>gv', { noremap = true })
      -- Basic indentation settings
      vim.o.tabstop = 4        -- Number of spaces that a <Tab> in the file counts for
      vim.o.shiftwidth = 4     -- Number of spaces to use for each step of (auto)indent
      vim.o.expandtab = true   -- Use spaces instead of tabs
      vim.o.autoindent = true  -- Copy indent from current line when starting a new line
      vim.o.smartindent = true -- Do smart autoindenting when starting a new line 
      -- Enable list mode
      vim.opt.list = true
      vim.opt.listchars:append({ tab = '>-', trail = 'x' })
      -- Enable undofile support
      vim.o.undofile = true
    '';

    globals.mapleader = " ";
    keymaps = [
      {
        mode = ["n" "t"];
        key = "<C-a>c";
        options = { noremap = true; desc = "Open new terminal"; };
        action = "<cmd>:term<cr>";
      }
      {
        mode = ["n"];
        key = "<C-a>x";
        options = { noremap = true; desc = "Close tab"; };
        action = "<cmd>:bd<cr>";
      }
      {
        mode = ["t"];
        key = "<C-a>x";
        options = { noremap = true; desc = "Close tab"; };
        action = "<cmd>:bd!<cr>";
      }
      {
        mode = ["n" "t"];
        key = "<C-a>s";
        options = { noremap = true; desc = "Pick buffer"; };
        action = "<cmd>:BufferLinePick<CR>";
      }
      {
        mode = "t";
        key = "<Esc><Esc>";
        options = { noremap = true; };
        action = "<C-\\><C-n>";
      }
      {
        mode = ["n"];
        key = "<leader>w";
        options = { noremap = true; desc = "+windows"; };
        action = "+windows";
      }
      {
        mode = ["n"];
        key = "<leader>w<Left>";
        options = { noremap = true; desc = "Move Left"; };
        action = "<C-w>h";
      }
      {
        mode = ["n"];
        key = "<leader>w<Right>";
        options = { noremap = true; desc = "Move Right"; };
        action = "<C-w>l";
      }
      {
        mode = ["n"];
        key = "<leader>w<Up>";
        options = { noremap = true; desc = "Move Up"; };
        action = "<C-w>k";
      }
      {
        mode = ["n"];
        key = "<leader>w<Down>";
        options = { noremap = true; desc = "Move Down"; };
        action = "<C-w>j";
      }
      {
        mode = ["n"];
        key = "<leader>wx";
        options = { noremap = true; desc = "Close Window"; };
        action = "<cmd>:close<cr>";
      }
      {
        mode = ["n"];
        key = "<leader>ws";
        options = { noremap = true; desc = "+splits"; };
        action = "+splits";
      }
      {
        mode = ["n"];
        key = "<leader>wsh";
        options = { noremap = true; desc = "Horizontal Split"; };
        action = "<cmd>:split<cr>";
      }
      {
        mode = ["n"];
        key = "<leader>wsv";
        options = { noremap = true; desc = "Vertical Split"; };
        action = "<cmd>:vsplit<cr>";
      }
    ];
  };

  programs.ssh = {
    enable = true; # Enable SSH module
    extraConfig = ''
      Host *
        ControlMaster auto
        ControlPath ~/.ssh/sockets/%r@%h-%p
        ControlPersist 600
    '';
  };

  home.packages = [
    pkgs.htop
    pkgs.zsh
    pkgs.xclip
    pkgs.ripgrep
    pkgs.waypipe
    pkgs.pwgen
    pkgs.neovim-remote
    #pkgs.pipx
    pkgs.rclone
    pkgs.pyright
    pkgs.mosh
    pkgs.jq
    pkgs.copier
    pkgs.pv
    #pkgs.poetry
    pkgs.nmap
    pkgs.dig
    pkgs.tree
    pkgs.curl
    pkgs.wget
    pkgs.wl-clipboard
    pkgs.atool
    pkgs.zig
    pkgs.comma

    (pkgs.writeShellScriptBin "poetry" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.poetry}/bin/poetry "$@"
    '')
    (pkgs.writeShellScriptBin "pipx" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.pipx}/bin/pipx "$@"
    '')

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
    autocd = false;

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
