#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <folder> [--no-ext]"
  exit 1
fi

FOLDER="$1"
SHOW_NO_EXT=false
if [ "${2:-}" == "--no-ext" ]; then
  SHOW_NO_EXT=true
fi

if [ ! -d "$FOLDER" ]; then
  echo "Error: directory '$FOLDER' does not exist."
  exit 1
fi

if $SHOW_NO_EXT; then
  echo "Список файлов БЕЗ расширения и их количество в папке $FOLDER:"
  find "$FOLDER" -type f | \
    awk -F/ '{print $NF}' | \
    grep -v '\.' | \
    sort | uniq -c | sort -nr
else
  echo "Список расширений файлов и количество в папке $FOLDER:"
  find "$FOLDER" -type f | \
    awk -F/ '{print $NF}' | grep '\.' | \
    sed -n 's/.*\.//p' | \
    sort | uniq -c | sort -nr
fi

