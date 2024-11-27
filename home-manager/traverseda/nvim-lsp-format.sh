#!/usr/bin/env bash

# This script formats all files in a given directory using Neovim's LSP

set -e

DIRECTORY=${1:-.}

# Find all files in the directory
find "$DIRECTORY" -type f | while read -r file; do
  echo "Formatting $file"
  nvim --headless -c "edit $file" -c "lua vim.lsp.buf.format()" -c "write" -c "quit"
done
