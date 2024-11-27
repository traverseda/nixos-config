{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # We use bufferline for the top line
    plugins.bufferline.enable = true;
    # And lualine for the bottom line
    plugins.lualine = {
      enable = true;
      sections = {
        lualine_c = [ "os.date('%X')" ];
        lualine_x = [
          { name = "hostname"; }
        ];
      };
    };

    # Enable which key
    plugins.which-key.enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      vim-suda
    ];

    # Enable autocomplete
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
          { name = "copilot"; }
          { name = "nvim_lsp"; }
          { name = "path"; }
          { name = "buffer"; }
          { name = "treesitter"; }
          { name = "bash"; }
        ];
      };
    };
    plugins.indent-blankline.enable = true;
    # plugins.lsp-format.enable = true;
    plugins.commentary.enable = true;
    plugins.lsp = {
      enable = true;
      servers = {
        ruff-lsp.enable = true;
        html.enable = true;
        dockerls.enable = true;
        yamlls = {
          enable = true;
          filetypes = [ "yaml" ];
        };
        nixd = {
          enable = true;

          settings = {
            formatting.command = [ "nixpkgs-fmt" ];
            nixpkgs.expr = "import <nixpkgs> {}";
          };
        };
      };
    };
    plugins.lsp-lines.enable = true;
    # plugins.lint = {
    #   enable = true;
    # };
    plugins.nix.enable = true;

    # plugins.clipboard-image = {
    #   enable = true;
    #   clipboardPackage = pkgs.xclip;
    # };

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

      function FormatFunction()
        vim.lsp.buf.format({
          async = true,
          range = {
            ["start"] = vim.api.nvim_buf_get_mark(0, "<"),
            ["end"] = vim.api.nvim_buf_get_mark(0, ">"),
          }
        })
      end

    '';

    globals.mapleader = " ";
    keymaps = [
      {
        # Clear the search buffer when I press esc twice
        mode = [ "n" "t" ];
        key = "<esc><esc>";
        options = { noremap = true; desc = "Clear search"; };
        action = ":nohlsearch<cr>";
      }
      {
        mode = "t";
        key = "<Esc><Esc>";
        options = { noremap = true; };
        action = "<C-\\><C-n>";
      }
      {
        mode = [ "n" "t" ];
        key = "<C-a>c";
        options = { noremap = true; desc = "Open new terminal"; };
        action = "<cmd>:term<cr>";
      }
      {
        mode = [ "n" ];
        key = "<C-a>x";
        options = { noremap = true; desc = "Close tab"; };
        action = "<cmd>:bd<cr>";
      }
      {
        mode = [ "t" ];
        key = "<C-a>x";
        options = { noremap = true; desc = "Close tab"; };
        action = "<cmd>:bd!<cr>";
      }
      {
        mode = [ "n" "t" ];
        key = "<C-a>s";
        options = { noremap = true; desc = "Pick buffer"; };
        action = "<cmd>:BufferLinePick<CR>";
      }
      {
        mode = [ "n" ];
        key = "<leader>w";
        options = { noremap = true; desc = "+windows"; };
        action = "+windows";
      }
      {
        mode = [ "n" ];
        key = "<leader>w<Left>";
        options = { noremap = true; desc = "Move Left"; };
        action = "<C-w>h";
      }
      {
        mode = [ "n" ];
        key = "<leader>w<Right>";
        options = { noremap = true; desc = "Move Right"; };
        action = "<C-w>l";
      }
      {
        mode = [ "n" ];
        key = "<leader>w<Up>";
        options = { noremap = true; desc = "Move Up"; };
        action = "<C-w>k";
      }
      {
        mode = [ "n" ];
        key = "<leader>w<Down>";
        options = { noremap = true; desc = "Move Down"; };
        action = "<C-w>j";
      }
      {
        mode = [ "n" ];
        key = "<leader>wx";
        options = { noremap = true; desc = "Close Window"; };
        action = "<cmd>:close<cr>";
      }
      {
        mode = [ "n" ];
        key = "<leader>f";
        options = { noremap = true; desc = "Format Document"; };
        action = "<cmd>lua vim.lsp.buf.format()<cr>";
      }
      {
        mode = [ "v" ];
        key = "<leader>f";
        options = { noremap = true; desc = "Format Selection"; };
        action = "<cmd>lua FormatFunction()<cr>";
      }
      {
        mode = [ "n" ];
        key = "<leader>ws";
        options = { noremap = true; desc = "+splits"; };
        action = "+splits";
      }
      {
        mode = [ "n" ];
        key = "<leader>wsh";
        options = { noremap = true; desc = "Horizontal Split"; };
        action = "<cmd>:split<cr>";
      }
      {
        mode = [ "n" ];
        key = "<leader>wsv";
        options = { noremap = true; desc = "Vertical Split"; };
        action = "<cmd>:vsplit<cr>";
      }
    ];
  };
}
