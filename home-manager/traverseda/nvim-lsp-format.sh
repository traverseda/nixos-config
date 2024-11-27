#!/usr/bin/env bash

# This script formats all files in a given directory using Neovim's LSP

set -e

FORCE=false
if [[ "$1" == "--force" ]]; then
  FORCE=true
  shift
fi

DIRECTORY=${1:-.}

# Find all files in the directory
find "$DIRECTORY" -type f | while read -r file; do
  if $FORCE || (git ls-files --error-unmatch "$file" > /dev/null 2>&1 && git diff --quiet "$file"); then
    echo "Formatting $file"
    nvim --headless -c "edit $file" -c "lua vim.lsp.buf.format()" -c "write" -c "quit"
  else
    echo "Skipping $file (not tracked or modified)"
  fi
done
