#!/bin/bash

# Usage:
# ./clean_elves_except.sh /path/to/folder keep1 keep2 ...
# Example:
# ./clean_elves_except.sh ./myenv py so pip activate open3d f2py f2py3

DIR="$1"
shift

KEEP_NAMES=("$@")

if [ -z "$DIR" ]; then
  echo "Usage: $0 /path/to/folder keep_name1 keep_name2 ..."
  exit 1
fi

if [ ! -d "$DIR" ]; then
  echo "Error: Directory $DIR does not exist."
  exit 1
fi

# Find ELF executables, exclude those with names in KEEP_NAMES, then delete them

find "$DIR" -type f -executable | while read -r file; do
  # Check if file is ELF executable
  if file "$file" | grep -q 'ELF'; then
    base=$(basename "$file")
    keep=false
    for name in "${KEEP_NAMES[@]}"; do
      if [[ "$base" == "$name" ]]; then
        keep=true
        break
      fi
    done
    if ! $keep; then
      echo "Removing ELF executable: $file"
      rm -f "$file"
    else
      echo "Keeping ELF executable: $file"
    fi
  fi
done

echo "Done removing ELF executables except: ${KEEP_NAMES[*]}"

