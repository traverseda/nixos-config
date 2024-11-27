#!/usr/bin/env bash

# This script formats all files in a given directory using Neovim's LSP,
# with support for logging and filtering by file extensions.

set -e

LOG_FILE="format.log"
FORCE=false
EXTENSIONS=()

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --force) FORCE=true ;;
    --ext) shift; EXTENSIONS+=("$1") ;;
    --log-file) shift; LOG_FILE="$1" ;;
    --help)
      echo "Usage: $0 [options] [directory]"
      echo "Options:"
      echo "  --force               Format all files, including untracked and modified files."
      echo "  --ext <extension>     Specify file extensions to format (e.g., --ext .py)."
      echo "  --log-file <file>     Specify log file (default: format.log)."
      echo "  --help                Display this help message."
      exit 0
      ;;
    *) DIRECTORY="$1" ;;
  esac
  shift
done

DIRECTORY=${DIRECTORY:-.}

# Initialize log file
echo "Formatting started at $(date)" > "$LOG_FILE"

# Function to filter files by extension
filter_by_extension() {
  local file="$1"
  if [[ "${#EXTENSIONS[@]}" -eq 0 ]]; then
    return 0  # No filtering, include all files
  fi
  for ext in "${EXTENSIONS[@]}"; do
    if [[ "$file" == *"$ext" ]]; then
      return 0  # Match found
    fi
  done
  return 1  # No match
}

# Get tracked and unmodified files in one pass
mapfile -t FILES < <(
  git -C "$DIRECTORY" ls-files -z | \
  xargs -0 git diff --quiet -- && git -C "$DIRECTORY" ls-files -z -- \
  || true
)

# Add untracked files if FORCE is true
if $FORCE; then
  mapfile -t UNTRACKED_FILES < <(git -C "$DIRECTORY" ls-files -o --exclude-standard -z)
  FILES+=("${UNTRACKED_FILES[@]}")
fi

# Filter files by extension
FILES=($(printf "%s\n" "${FILES[@]}" | while IFS= read -r file; do
  filter_by_extension "$file" && echo "$file"
done))

# Format files in one Neovim session
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No files to format." | tee -a "$LOG_FILE"
  exit 0
fi

echo "Formatting ${#FILES[@]} file(s)..." | tee -a "$LOG_FILE"

# Format files in a batch and log the results
{
  nvim --headless \
    -c "for file in ${FILES[@]}; execute 'edit' fnameescape(file) | lua vim.lsp.buf.format({async = false}) | write | bdelete! | endfor" \
    -c "quit"
} &>> "$LOG_FILE" || echo "Error during formatting. Check $LOG_FILE for details."

echo "Formatting complete." | tee -a "$LOG_FILE"

