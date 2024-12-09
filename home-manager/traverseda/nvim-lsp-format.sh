#!/usr/bin/env bash

set -euo pipefail

# Default values
DRY_RUN=false
FORCE=false
FILES_TO_FORMAT=()

# Function to display help
function show_help() {
  echo "Usage: $0 [options] [files...]"
  echo ""
  echo "Options:"
  echo "  --force       Format all committed files, even if they are modified"
  echo "  --dry-run     Show which files would be formatted without making changes"
  echo "  -h, --help    Display this help message"
  exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    *)
      FILES_TO_FORMAT+=("$1")
      shift
      ;;
  esac
done

# Function to log messages to stderr
function log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Function to get all committed files, filtered by .gitignore
function get_committed_files() {
  git ls-files --cached --others --exclude-standard
}

# Function to format a file using Neovim
function format_file() {
  local file="$1"
  log_message "Formatting $file"
  nvim --headless -c "edit $file" -c "lua vim.lsp.buf.format()" -c "write" -c "quit"
}

log_message "Starting script..."

# Determine which files to format
if [[ ${#FILES_TO_FORMAT[@]} -eq 0 ]]; then
  log_message "No files specified. Fetching files from Git..."
  mapfile -t FILES_TO_FORMAT < <(get_committed_files)
fi

log_message "Initial list of files: ${FILES_TO_FORMAT[*]}"

# Process each file
for file in "${FILES_TO_FORMAT[@]}"; do
  if [[ -f "$file" ]]; then
    if $FORCE || (git ls-files --error-unmatch "$file" > /dev/null 2>&1 && git diff --quiet "$file"); then
      if $DRY_RUN; then
        log_message "Would format: $file"
      else
        format_file "$file"
      fi
    else
      if ! git diff --quiet "$file"; then
        log_message "Skipping modified file: $file"
      fi
    fi
  else
    log_message "Skipping invalid file: $file"
  fi
done

log_message "Formatting complete."
